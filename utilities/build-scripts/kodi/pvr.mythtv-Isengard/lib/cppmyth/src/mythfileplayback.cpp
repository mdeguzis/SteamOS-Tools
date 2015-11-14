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

#include "mythfileplayback.h"
#include "mythlivetvplayback.h"
#include "mythdebug.h"
#include "private/os/threads/mutex.h"
#include "private/builtin.h"

#include <limits>
#include <cstdio>

using namespace Myth;

///////////////////////////////////////////////////////////////////////////////
////
//// Protocol connection to control playback
////

FilePlayback::FilePlayback(const std::string& server, unsigned port)
: ProtoPlayback(server, port)
, m_transfer(NULL)
{
  ProtoPlayback::Open();
}

FilePlayback::~FilePlayback()
{
  Close();
}

bool FilePlayback::Open()
{
  // Begin critical section
  OS::CLockGuard lock(*m_mutex);
  if (ProtoPlayback::IsOpen())
    return true;
  return ProtoPlayback::Open();
}

void FilePlayback::Close()
{
  // Begin critical section
  OS::CLockGuard lock(*m_mutex);
  CloseTransfer();
  ProtoPlayback::Close();
}

bool FilePlayback::OpenTransfer(const std::string& pathname, const std::string& sgname)
{
  // Begin critical section
  OS::CLockGuard lock(*m_mutex);
  if (!ProtoPlayback::IsOpen())
    return false;
  CloseTransfer();
  m_transfer.reset(new ProtoTransfer(m_server, m_port, pathname, sgname));
  if (m_transfer->Open())
    return true;
  return false;
}

void FilePlayback::CloseTransfer()
{
  // Begin critical section
  OS::CLockGuard lock(*m_mutex);
  if (m_transfer)
  {
    TransferDone(*m_transfer);
    m_transfer->Close();
    m_transfer.reset();
  }
}

bool FilePlayback::TransferIsOpen()
{
  ProtoTransferPtr transfer(m_transfer);
  if (transfer)
    return ProtoPlayback::TransferIsOpen(*transfer);
  return false;
}

int64_t FilePlayback::GetSize() const
{
  ProtoTransferPtr transfer(m_transfer);
  if (transfer)
    return transfer->GetSize();
  return 0;
}

int FilePlayback::Read(void *buffer, unsigned n)
{
  ProtoTransferPtr transfer(m_transfer);
  if (transfer)
  {
    int r = 0;
    int64_t s = transfer->GetRemaining(); // Acceptable block size
    if (s > 0)
    {
      if (s < (int64_t)n)
      n = (unsigned)s ;
      // Request block data from transfer socket
      r = TransferRequestBlock(*transfer, buffer, n);
    }
    return r;
  }
  return -1;
}

int64_t FilePlayback::Seek(int64_t offset, WHENCE_t whence)
{
  ProtoTransferPtr transfer(m_transfer);
  if (transfer)
    return TransferSeek(*transfer, offset, whence);
  return -1;
}

int64_t FilePlayback::GetPosition() const
{
  ProtoTransferPtr transfer(m_transfer);
  if (transfer)
    return transfer->GetPosition();
  return 0;
}
