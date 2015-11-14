/*
 *      Copyright (C) 2014 Jean-Luc Barriere
 *
 *  This Program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2, or (at your option)
 *  any later version.
 *
 *  This Program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; see the file COPYING.  If not, write to
 *  the Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston,
 *  MA 02110-1301 USA
 *  http://www.gnu.org/copyleft/gpl.html
 *
 */

#include "mythprotoplayback.h"
#include "../mythdebug.h"
#include "../private/mythsocket.h"
#include "../private/os/threads/mutex.h"
#include "../private/builtin.h"

#include <limits>
#include <cstdio>

#ifdef __WINDOWS__
#include <Ws2tcpip.h>
#else
#include <sys/socket.h> // for recv
#include <sys/select.h> // for select
#endif /* __WINDOWS__ */

using namespace Myth;

///////////////////////////////////////////////////////////////////////////////
////
//// Protocol connection to control playback
////

ProtoPlayback::ProtoPlayback(const std::string& server, unsigned port)
: ProtoBase(server, port)
{
}

bool ProtoPlayback::Open()
{
  bool ok = false;

  if (!OpenConnection(PROTO_PLAYBACK_RCVBUF))
    return false;

  if (m_protoVersion >= 75)
    ok = Announce75();

  if (ok)
    return true;
  Close();
  return false;
}

void ProtoPlayback::Close()
{
  ProtoBase::Close();
  // Clean hanging and disable retry
  m_tainted = m_hang = false;
}

bool ProtoPlayback::IsOpen()
{
  // Try reconnect
  if (m_hang)
    return ProtoPlayback::Open();
  return ProtoBase::IsOpen();
}

bool ProtoPlayback::Announce75()
{
  OS::CLockGuard lock(*m_mutex);

  std::string cmd("ANN Playback ");
  cmd.append(m_socket->GetMyHostName()).append(" 0");
  if (!SendCommand(cmd.c_str()))
    return false;

  std::string field;
  if (!ReadField(field) || !IsMessageOK(field))
    goto out;
  return true;

out:
  FlushMessage();
  return false;
}

void ProtoPlayback::TransferDone75(ProtoTransfer& transfer)
{
  char buf[32];

  OS::CLockGuard lock(*m_mutex);
  if (!transfer.IsOpen())
    return;
  std::string cmd("QUERY_FILETRANSFER ");
  uint32_to_string(transfer.GetFileId(), buf);
  cmd.append(buf).append(PROTO_STR_SEPARATOR).append("DONE");
  if (SendCommand(cmd.c_str()))
  {
    std::string field;
    if (!ReadField(field) || !IsMessageOK(field))
      FlushMessage();
  }
}

bool ProtoPlayback::TransferIsOpen75(ProtoTransfer& transfer)
{
  char buf[32];
  std::string field;
  int8_t status = 0;

  OS::CLockGuard lock(*m_mutex);
  if (!IsOpen())
    return false;
  std::string cmd("QUERY_FILETRANSFER ");
  uint32_to_string(transfer.GetFileId(), buf);
  cmd.append(buf);
  cmd.append(PROTO_STR_SEPARATOR);
  cmd.append("IS_OPEN");

  if (!SendCommand(cmd.c_str()))
    return false;
  if (!ReadField(field) || 0 != string_to_int8(field.c_str(), &status))
  {
      FlushMessage();
      return false;
  }
  if (status == 0)
    return false;
  return true;
}

int ProtoPlayback::TransferRequestBlock(ProtoTransfer& transfer, void *buffer, unsigned n)
{
  bool request = false, data = false;
  int r = 0, nfds = 0, fdc, fdd;
  char *p = (char*)buffer;
  struct timeval tv;
  fd_set fds;
  unsigned s = 0;

  int64_t filePosition = transfer.GetPosition();
  int64_t fileRequest = transfer.GetRequested();

  if (n == 0)
    return n;

  fdc = GetSocket();
  if (INVALID_SOCKET_VALUE == (tcp_socket_t)fdc)
    return -1;
  fdd = transfer.GetSocket();
  if (INVALID_SOCKET_VALUE == (tcp_socket_t)fdd)
    return -1;
  // Max size is RCVBUF size
  if (n > PROTO_TRANSFER_RCVBUF)
    n = PROTO_TRANSFER_RCVBUF;
  if ((filePosition + n) > fileRequest)
  {
    // Begin critical section
    m_mutex->Lock();
    bool ok = TransferRequestBlock75(transfer, n);
    if (!ok)
    {
      m_mutex->Unlock();
      goto err;
    }
    request = true;
  }

  do
  {
    FD_ZERO(&fds);
    if (request)
    {
      FD_SET((tcp_socket_t)fdc, &fds);
      if (nfds < fdc)
        nfds = fdc;
    }
    FD_SET((tcp_socket_t)fdd, &fds);
    if (nfds < fdd)
      nfds = fdd;

    if (data)
    {
      // Read directly to get all queued packets
      tv.tv_sec = 0;
      tv.tv_usec = 0;
    }
    else
    {
      // Wait and read for new packet
      tv.tv_sec = 10;
      tv.tv_usec = 0;
    }

    r = select (nfds + 1, &fds, NULL, NULL, &tv);
    if (r < 0)
    {
      DBG(MYTH_DBG_ERROR, "%s: select error (%d)\n", __FUNCTION__, r);
      goto err;
    }
    if (r == 0 && !data)
    {
      DBG(MYTH_DBG_ERROR, "%s: select timeout\n", __FUNCTION__);
      goto err;
    }
    // Check for data
    data = false;
    if (FD_ISSET((tcp_socket_t)fdd, &fds))
    {
      r = recv((tcp_socket_t)fdd, p, (size_t)(n - s), 0);
      if (r < 0)
      {
        DBG(MYTH_DBG_ERROR, "%s: recv data error (%d)\n", __FUNCTION__, r);
        goto err;
      }
      if (r > 0)
      {
        data = true;
        s += r;
        p += r;
        filePosition += r;
        transfer.SetPosition(filePosition);
      }
    }
    // Check for response of request
    if (request && FD_ISSET((tcp_socket_t)fdc, &fds))
    {
      int32_t rlen = TransferRequestBlockFeedback75();
      request = false; // request is completed
      m_mutex->Unlock();
      if (rlen < 0)
        goto err;
      DBG(MYTH_DBG_DEBUG, "%s: receive block size (%u)\n", __FUNCTION__, (unsigned)rlen);
      if (rlen == 0 && !data)
        break; // no more data
      fileRequest += rlen;
      transfer.SetRequested(fileRequest);
    }
  } while (request || data || !s);
  DBG(MYTH_DBG_DEBUG, "%s: data read (%u)\n", __FUNCTION__, s);
  return (int)s;
err:
  if (request)
  {
    if (RcvMessageLength())
      FlushMessage();
    m_mutex->Unlock();
  }
  // Recover the file position or die
  if (TransferSeek(transfer, filePosition, WHENCE_SET) < 0)
    HangException();
  return -1;
}

bool ProtoPlayback::TransferRequestBlock75(ProtoTransfer& transfer, unsigned n)
{
  // Note: Caller has to hold mutex until feedback or cancel point
  char buf[32];

  if (!transfer.IsOpen())
    return false;
  std::string cmd("QUERY_FILETRANSFER ");
  uint32_to_string(transfer.GetFileId(), buf);
  cmd.append(buf);
  cmd.append(PROTO_STR_SEPARATOR);
  cmd.append("REQUEST_BLOCK");
  cmd.append(PROTO_STR_SEPARATOR);
  uint32_to_string(n, buf);
  cmd.append(buf);

  // No wait for feedback
  if (!SendCommand(cmd.c_str(), false))
    return false;
  return true;
}

int32_t ProtoPlayback::TransferRequestBlockFeedback75()
{
  int32_t rlen = 0;
  std::string field;
  if (!RcvMessageLength() || !ReadField(field) || 0 != string_to_int32(field.c_str(), &rlen) || rlen < 0)
  {
    DBG(MYTH_DBG_ERROR, "%s: invalid response for request block (%s)\n", __FUNCTION__, field.c_str());
    FlushMessage();
    return -1;
  }
  return rlen;
}

int64_t ProtoPlayback::TransferSeek75(ProtoTransfer& transfer, int64_t offset, WHENCE_t whence)
{
  char buf[32];
  int64_t position = 0;
  std::string field;

  int64_t filePosition = transfer.GetPosition();
  int64_t fileSize = transfer.GetSize();

  // Check offset
  switch (whence)
  {
    case WHENCE_CUR:
      if (offset == 0)
        return filePosition;
      position = filePosition + offset;
      if (position < 0 || position > fileSize)
        return -1;
      break;
    case WHENCE_SET:
      if (offset == filePosition)
        return filePosition;
      if (offset < 0 || offset > fileSize)
        return -1;
      break;
    case WHENCE_END:
      position = fileSize - offset;
      if (position < 0 || position > fileSize)
        return -1;
      break;
    default:
      return -1;
  }

  OS::CLockGuard lock(*m_mutex);
  if (!transfer.IsOpen())
    return -1;
  std::string cmd("QUERY_FILETRANSFER ");
  uint32_to_string(transfer.GetFileId(), buf);
  cmd.append(buf);
  cmd.append(PROTO_STR_SEPARATOR);
  cmd.append("SEEK");
  cmd.append(PROTO_STR_SEPARATOR);
  int64_to_string(offset, buf);
  cmd.append(buf);
  cmd.append(PROTO_STR_SEPARATOR);
  int8_to_string(whence, buf);
  cmd.append(buf);
  cmd.append(PROTO_STR_SEPARATOR);
  int64_to_string(filePosition, buf);
  cmd.append(buf);

  if (!SendCommand(cmd.c_str()))
    return -1;
  if (!ReadField(field) || 0 != string_to_int64(field.c_str(), &position))
  {
      FlushMessage();
      return -1;
  }
  // Reset transfer
  transfer.Flush();
  transfer.SetRequested(position);
  transfer.SetPosition(position);
  return position;
}
