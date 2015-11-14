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

#include "mythprotobase.h"
#include "../mythdebug.h"
#include "../private/mythsocket.h"
#include "../private/os/threads/mutex.h"
#include "../private/cppdef.h"
#include "../private/builtin.h"

#include <limits>
#include <cstdio>

using namespace Myth;

typedef struct
{
  unsigned version;
  char token[44]; // up to 43 chars used in v87 + the terminating NULL character
} myth_protomap_t;

static myth_protomap_t protomap[] = {
  {87, "(ノಠ益ಠ)ノ彡┻━┻_No_entiendo!)"},
  {86, "(ノಠ益ಠ)ノ彡┻━┻"},
  {85, "BluePool"},
  {84, "CanaryCoalmine"},
  {83, "BreakingGlass"},
  {82, "IdIdO"},
  {81, "MultiRecDos"},
  {80, "TaDah!"},
  {79, "BasaltGiant"},
  {77, "WindMark"},
  {76, "FireWilde"},
  {75, "SweetRock"},
  {0, ""}
};

ProtoBase::ProtoBase(const std::string& server, unsigned port)
: m_mutex(new OS::CMutex)
, m_socket(new TcpSocket())
, m_protoVersion(0)
, m_server(server)
, m_port(port)
, m_hang(false)
, m_tainted(false)
, m_msgLength(0)
, m_msgConsumed(0)
, m_isOpen(false)
, m_protoError(ERROR_NO_ERROR)
{
  m_socket->SetReadAttempt(6); // 60 sec to hang up
}

ProtoBase::~ProtoBase()
{
  this->Close();
  SAFE_DELETE(m_socket);
  SAFE_DELETE(m_mutex);
}

void ProtoBase::HangException()
{
  DBG(MYTH_DBG_ERROR, "%s: protocol connection hang with error %d\n", __FUNCTION__, m_socket->GetErrNo());
  m_tainted = m_hang = true;
  ProtoBase::Close();
  // Note: Opening connection successfully will reset m_hang
}

bool ProtoBase::SendCommand(const char *cmd, bool feedback)
{
  char buf[9];
  size_t l = strlen(cmd);

  if (m_msgConsumed != m_msgLength)
  {
    DBG(MYTH_DBG_ERROR, "%s: did not consume everything\n", __FUNCTION__);
    FlushMessage();
  }

  if (l > 0 && l < PROTO_SENDMSG_MAXSIZE)
  {
    std::string msg;
    msg.reserve(l + 8);
    sprintf(buf, "%-8u", (unsigned)l);
    msg.append(buf).append(cmd);
    DBG(MYTH_DBG_PROTO, "%s: %s\n", __FUNCTION__, cmd);
    if (m_socket->SendMessage(msg.c_str(), msg.size()))
    {
      if (feedback)
        return RcvMessageLength();
      return true;
    }
    DBG(MYTH_DBG_ERROR, "%s: failed (%d)\n", __FUNCTION__, m_socket->GetErrNo());
    HangException();
    return false;
  }
  DBG(MYTH_DBG_ERROR, "%s: message size out of bound (%d)\n", __FUNCTION__, (int)l);
  return false;
}

size_t ProtoBase::GetMessageLength() const
{
  return m_msgLength;
}

/**
 * Read one field from the backend response
 * @param field
 * @return true : false
 */
bool ProtoBase::ReadField(std::string& field)
{
  const char *str_sep = PROTO_STR_SEPARATOR;
  size_t str_sep_len = PROTO_STR_SEPARATOR_LEN;
  char buf[PROTO_BUFFER_SIZE];
  size_t p = 0, p_ss = 0, l = m_msgLength, c = m_msgConsumed;

  field.clear();
  if ( c >= l)
    return false;

  for (;;)
  {
    if (l > c)
    {
      if (m_socket->ReadResponse(&buf[p], 1) < 1)
      {
        HangException();
        return false;
      }
      ++c;
      if (buf[p++] == str_sep[p_ss])
      {
        if (++p_ss >= str_sep_len)
        {
          // Append data until separator before exit
          buf[p - str_sep_len] = '\0';
          field.append(buf);
          break;
        }
      }
      else
      {
        p_ss = 0;
        if (p > (PROTO_BUFFER_SIZE - 2 - str_sep_len))
        {
          // Append data before flushing to refill the following
          buf[p] = '\0';
          field.append(buf);
          p = 0;
        }
      }
    }
    else
    {
      // All is consumed. Append rest of data before exit
      buf[p] = '\0';
      field.append(buf);
      break;
    }
  }
  // Renew consumed or reset when no more data
  if (l > c)
    m_msgConsumed = c;
  else
    m_msgConsumed = m_msgLength = 0;
  return true;
}

bool ProtoBase::IsMessageOK(const std::string& field) const
{
  if (field.size() == 2)
  {
    if ((field[0] == 'O' || field[0] == 'o') && (field[1] == 'K' || field[1] == 'k'))
      return true;
  }
  return false;
}

size_t ProtoBase::FlushMessage()
{
  char buf[PROTO_BUFFER_SIZE];
  size_t r, n = 0, f = m_msgLength - m_msgConsumed;

  while (f > 0)
  {
    r = (f > PROTO_BUFFER_SIZE ? PROTO_BUFFER_SIZE : f);
    if (m_socket->ReadResponse(buf, r) != r)
    {
      HangException();
      break;
    }
    f -= r;
    n += r;
  }
  m_msgLength = m_msgConsumed = 0;
  return n;
}

bool ProtoBase::RcvMessageLength()
{
  char buf[9];
  uint32_t val = 0;

  // If not placed on head of new response then break
  if (m_msgLength > 0)
    return false;

  if (m_socket->ReadResponse(buf, 8) == 8)
  {
    if (0 == string_to_uint32(buf, &val))
    {
      DBG(MYTH_DBG_PROTO, "%s: %" PRIu32 "\n", __FUNCTION__, val);
      m_msgLength = (size_t)val;
      m_msgConsumed = 0;
      return true;
    }
    DBG(MYTH_DBG_ERROR, "%s: failed ('%s')\n", __FUNCTION__, buf);
  }
  HangException();
  return false;
}

/**
 * Parse feedback of command MYTH_PROTO_VERSION and return protocol version
 * of backend
 * @param version
 * @return true : false
 */
bool ProtoBase::RcvVersion(unsigned *version)
{
  std::string field;
  uint32_t val = 0;

  /*
   * The string we just consumed was either "ACCEPT" or "REJECT".  In
   * either case, the number following it is the correct version, and
   * we use it as an unsigned.
   */
  if (!ReadField(field))
    goto out;
  if (!ReadField(field))
    goto out;
  if (FlushMessage())
  {
    DBG(MYTH_DBG_ERROR, "%s: did not consume everything\n", __FUNCTION__);
    return false;
  }
  if (0 != string_to_uint32(field.c_str(), &val))
    goto out;
  *version = (unsigned)val;
  return true;

out:
  DBG(MYTH_DBG_ERROR, "%s: failed ('%s')\n", __FUNCTION__, field.c_str());
  FlushMessage();
  return false;
}

bool ProtoBase::OpenConnection(int rcvbuf)
{
  static unsigned my_version = 0;
  char cmd[256];
  myth_protomap_t *map;
  unsigned tmp_ver;

  OS::CLockGuard lock(*m_mutex);

  if (!my_version)
    // try first version of the map
    tmp_ver = protomap->version;
  else
    // try previously agreed version
    tmp_ver = my_version;

  if (m_isOpen)
    ProtoBase::Close();
  // Reset error status
  m_protoError = ERROR_NO_ERROR;
  for (;;)
  {
    // Reset to allow downgrade/upgrade
    map = protomap;
    while (map->version != 0 && map->version != tmp_ver)
      ++map;

    if (map->version == 0)
    {
      m_protoError = ERROR_UNKNOWN_VERSION;
      DBG(MYTH_DBG_ERROR, "%s: failed to connect with any version\n", __FUNCTION__);
      break;
    }

    if (!m_socket->Connect(m_server.c_str(), m_port, rcvbuf))
    {
      // hang will remain up allowing retry
      m_hang = true;
      m_protoError = ERROR_SERVER_UNREACHABLE;
      break;
    }
    // Now socket is connected: Reset hang
    m_hang = false;

    sprintf(cmd, "MYTH_PROTO_VERSION %" PRIu32 " %s", map->version, map->token);

    if (!SendCommand(cmd) || !RcvVersion(&tmp_ver))
    {
      m_protoError = ERROR_SOCKET_ERROR;
      break;
    }

    DBG(MYTH_DBG_DEBUG, "%s: asked for version %" PRIu32 ", got version %" PRIu32 "\n",
            __FUNCTION__, map->version, tmp_ver);

    if (map->version == tmp_ver)
    {
      DBG(MYTH_DBG_DEBUG, "%s: agreed on version %u\n", __FUNCTION__, tmp_ver);
      if (tmp_ver != my_version)
        my_version = tmp_ver; // Store agreed version for next time
      m_isOpen = true;
      m_protoVersion = tmp_ver;
      return true;
    }
    // Retry with the returned version
    m_socket->Disconnect();
  }

  m_socket->Disconnect();
  m_isOpen = false;
  m_protoVersion = 0;
  return false;
}

void ProtoBase::Close()
{
  const char *cmd = "DONE";

  OS::CLockGuard lock(*m_mutex);

  if (m_socket->IsConnected())
  {
    // Close gracefully by sending DONE message before disconnect
    if (m_isOpen && !m_hang)
    {
      if (SendCommand(cmd, false))
        DBG(MYTH_DBG_PROTO, "%s: done\n", __FUNCTION__);
      else
        DBG(MYTH_DBG_WARN, "%s: gracefully failed (%d)\n", __FUNCTION__, m_socket->GetErrNo());
    }
    m_socket->Disconnect();
  }
  m_isOpen = false;
  m_msgLength = m_msgConsumed = 0;
}

unsigned ProtoBase::GetProtoVersion() const
{
  if (m_isOpen)
    return m_protoVersion;
  return 0;
}

std::string ProtoBase::GetServer() const
{
  return m_server;
}

unsigned ProtoBase::GetPort() const
{
  return m_port;
}

int ProtoBase::GetSocketErrNo() const
{
  return m_socket->GetErrNo();
}

int ProtoBase::GetSocket() const
{
  return (int)(m_socket->GetSocket());
}

bool ProtoBase::HasHanging() const
{
  return m_tainted;
}

void ProtoBase::CleanHanging()
{
  m_tainted = false;
}

ProtoBase::ERROR_t ProtoBase::GetProtoError() const
{
  return m_protoError;
}

ProgramPtr ProtoBase::RcvProgramInfo75()
{
  int64_t tmpi;
  std::string field;
  ProgramPtr program(new Program());
  int i = 0;

  ++i;
  if (!ReadField(program->title))
    goto out;
  ++i;
  if (!ReadField(program->subTitle))
    goto out;
  ++i;
  if (!ReadField(program->description))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->season)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->episode)))
    goto out;
  ++i;
  if (!ReadField(program->category))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->channel.chanId)))
    goto out;
  ++i;
  if (!ReadField(program->channel.chanNum))
    goto out;
  ++i;
  if (!ReadField(program->channel.callSign))
    goto out;
  ++i;
  if (!ReadField(program->channel.channelName))
    goto out;
  ++i;
  if (!ReadField(program->fileName))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &(program->fileSize)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->startTime = (time_t)tmpi;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->endTime = (time_t)tmpi;
  ++i;
  if (!ReadField(field)) // findid
    goto out;
  ++i;
  if (!ReadField(program->hostName))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->channel.sourceId)))
    goto out;
  ++i;
  if (!ReadField(field)) // cardid
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->channel.inputId)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int32(field.c_str(), &(program->recording.priority)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int8(field.c_str(), &(program->recording.status)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->recording.recordId)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint8(field.c_str(), &(program->recording.recType)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint8(field.c_str(), &(program->recording.dupInType)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint8(field.c_str(), &(program->recording.dupMethod)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->recording.startTs = (time_t)tmpi;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->recording.endTs = (time_t)tmpi;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->programFlags)))
    goto out;
  ++i;
  if (!ReadField(program->recording.recGroup))
    goto out;
  ++i;
  if (!ReadField(program->channel.chanFilters))
    goto out;
  ++i;
  if (!ReadField(program->seriesId))
    goto out;
  ++i;
  if (!ReadField(program->programId))
    goto out;
  ++i;
  if (!ReadField(program->inetref))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->lastModified = (time_t)tmpi;
  ++i;
  if (!ReadField(program->stars))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_time(field.c_str(), &(program->airdate)))
    goto out;
  ++i;
  if (!ReadField(program->recording.playGroup))
    goto out;
  ++i;
  if (!ReadField(field)) // recpriority2
    goto out;
  ++i;
  if (!ReadField(field)) // parentid
    goto out;
  ++i;
  if (!ReadField(program->recording.storageGroup))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->audioProps)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->videoProps)))
    goto out;
  return program;
out:
  DBG(MYTH_DBG_ERROR, "%s: failed (%d) buf='%s'\n", __FUNCTION__, i, field.c_str());
  program.reset();
  return program;
}

ProgramPtr ProtoBase::RcvProgramInfo76()
{
  int64_t tmpi;
  std::string field;
  ProgramPtr program(new Program());
  int i = 0;

  ++i;
  if (!ReadField(program->title))
    goto out;
  ++i;
  if (!ReadField(program->subTitle))
    goto out;
  ++i;
  if (!ReadField(program->description))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->season)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->episode)))
    goto out;
  ++i;
  if (!ReadField(field)) // syndicated episode
    goto out;
  ++i;
  if (!ReadField(program->category))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->channel.chanId)))
    goto out;
  ++i;
  if (!ReadField(program->channel.chanNum))
    goto out;
  ++i;
  if (!ReadField(program->channel.callSign))
    goto out;
  ++i;
  if (!ReadField(program->channel.channelName))
    goto out;
  ++i;
  if (!ReadField(program->fileName))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &(program->fileSize)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->startTime = (time_t)tmpi;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->endTime = (time_t)tmpi;
  ++i;
  if (!ReadField(field)) // findid
    goto out;
  ++i;
  if (!ReadField(program->hostName))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->channel.sourceId)))
    goto out;
  ++i;
  if (!ReadField(field)) // cardid
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->channel.inputId)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int32(field.c_str(), &(program->recording.priority)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int8(field.c_str(), &(program->recording.status)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->recording.recordId)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint8(field.c_str(), &(program->recording.recType)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint8(field.c_str(), &(program->recording.dupInType)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint8(field.c_str(), &(program->recording.dupMethod)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->recording.startTs = (time_t)tmpi;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->recording.endTs = (time_t)tmpi;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->programFlags)))
    goto out;
  ++i;
  if (!ReadField(program->recording.recGroup))
    goto out;
  ++i;
  if (!ReadField(program->channel.chanFilters))
    goto out;
  ++i;
  if (!ReadField(program->seriesId))
    goto out;
  ++i;
  if (!ReadField(program->programId))
    goto out;
  ++i;
  if (!ReadField(program->inetref))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->lastModified = (time_t)tmpi;
  ++i;
  if (!ReadField(program->stars))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_time(field.c_str(), &(program->airdate)))
    goto out;
  ++i;
  if (!ReadField(program->recording.playGroup))
    goto out;
  ++i;
  if (!ReadField(field)) // recpriority2
    goto out;
  ++i;
  if (!ReadField(field)) // parentid
    goto out;
  ++i;
  if (!ReadField(program->recording.storageGroup))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->audioProps)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->videoProps)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->subProps)))
    goto out;
  ++i;
  if (!ReadField(field)) // year
    goto out;
  ++i;
  if (!ReadField(field)) // part number
    goto out;
  ++i;
  if (!ReadField(field)) // part total
    goto out;
  return program;
out:
  DBG(MYTH_DBG_ERROR, "%s: failed (%d) buf='%s'\n", __FUNCTION__, i, field.c_str());
  program.reset();
  return program;
}

ProgramPtr ProtoBase::RcvProgramInfo79()
{
  int64_t tmpi;
  std::string field;
  ProgramPtr program(new Program());
  int i = 0;

  ++i;
  if (!ReadField(program->title))
    goto out;
  ++i;
  if (!ReadField(program->subTitle))
    goto out;
  ++i;
  if (!ReadField(program->description))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->season)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->episode)))
    goto out;
  ++i;
  if (!ReadField(field)) // total episodes
    goto out;
  ++i;
  if (!ReadField(field)) // syndicated episode
    goto out;
  ++i;
  if (!ReadField(program->category))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->channel.chanId)))
    goto out;
  ++i;
  if (!ReadField(program->channel.chanNum))
    goto out;
  ++i;
  if (!ReadField(program->channel.callSign))
    goto out;
  ++i;
  if (!ReadField(program->channel.channelName))
    goto out;
  ++i;
  if (!ReadField(program->fileName))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &(program->fileSize)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->startTime = (time_t)tmpi;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->endTime = (time_t)tmpi;
  ++i;
  if (!ReadField(field)) // findid
    goto out;
  ++i;
  if (!ReadField(program->hostName))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->channel.sourceId)))
    goto out;
  ++i;
  if (!ReadField(field)) // cardid
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->channel.inputId)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int32(field.c_str(), &(program->recording.priority)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int8(field.c_str(), &(program->recording.status)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->recording.recordId)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint8(field.c_str(), &(program->recording.recType)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint8(field.c_str(), &(program->recording.dupInType)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint8(field.c_str(), &(program->recording.dupMethod)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->recording.startTs = (time_t)tmpi;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->recording.endTs = (time_t)tmpi;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->programFlags)))
    goto out;
  ++i;
  if (!ReadField(program->recording.recGroup))
    goto out;
  ++i;
  if (!ReadField(program->channel.chanFilters))
    goto out;
  ++i;
  if (!ReadField(program->seriesId))
    goto out;
  ++i;
  if (!ReadField(program->programId))
    goto out;
  ++i;
  if (!ReadField(program->inetref))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->lastModified = (time_t)tmpi;
  ++i;
  if (!ReadField(program->stars))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_time(field.c_str(), &(program->airdate)))
    goto out;
  ++i;
  if (!ReadField(program->recording.playGroup))
    goto out;
  ++i;
  if (!ReadField(field)) // recpriority2
    goto out;
  ++i;
  if (!ReadField(field)) // parentid
    goto out;
  ++i;
  if (!ReadField(program->recording.storageGroup))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->audioProps)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->videoProps)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->subProps)))
    goto out;
  ++i;
  if (!ReadField(field)) // year
    goto out;
  ++i;
  if (!ReadField(field)) // part number
    goto out;
  ++i;
  if (!ReadField(field)) // part total
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->catType = CategoryTypeToString(m_protoVersion, CategoryTypeFromNum(m_protoVersion, (int)tmpi));
  return program;
out:
  DBG(MYTH_DBG_ERROR, "%s: failed (%d) buf='%s'\n", __FUNCTION__, i, field.c_str());
  program.reset();
  return program;
}

ProgramPtr ProtoBase::RcvProgramInfo82()
{
  int64_t tmpi;
  std::string field;
  ProgramPtr program(new Program());
  int i = 0;

  ++i;
  if (!ReadField(program->title))
    goto out;
  ++i;
  if (!ReadField(program->subTitle))
    goto out;
  ++i;
  if (!ReadField(program->description))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->season)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->episode)))
    goto out;
  ++i;
  if (!ReadField(field)) // total episodes
    goto out;
  ++i;
  if (!ReadField(field)) // syndicated episode
    goto out;
  ++i;
  if (!ReadField(program->category))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->channel.chanId)))
    goto out;
  ++i;
  if (!ReadField(program->channel.chanNum))
    goto out;
  ++i;
  if (!ReadField(program->channel.callSign))
    goto out;
  ++i;
  if (!ReadField(program->channel.channelName))
    goto out;
  ++i;
  if (!ReadField(program->fileName))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &(program->fileSize)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->startTime = (time_t)tmpi;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->endTime = (time_t)tmpi;
  ++i;
  if (!ReadField(field)) // findid
    goto out;
  ++i;
  if (!ReadField(program->hostName))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->channel.sourceId)))
    goto out;
  ++i;
  if (!ReadField(field)) // cardid
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->channel.inputId)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int32(field.c_str(), &(program->recording.priority)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int8(field.c_str(), &(program->recording.status)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->recording.recordId)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint8(field.c_str(), &(program->recording.recType)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint8(field.c_str(), &(program->recording.dupInType)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint8(field.c_str(), &(program->recording.dupMethod)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->recording.startTs = (time_t)tmpi;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->recording.endTs = (time_t)tmpi;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->programFlags)))
    goto out;
  ++i;
  if (!ReadField(program->recording.recGroup))
    goto out;
  ++i;
  if (!ReadField(program->channel.chanFilters))
    goto out;
  ++i;
  if (!ReadField(program->seriesId))
    goto out;
  ++i;
  if (!ReadField(program->programId))
    goto out;
  ++i;
  if (!ReadField(program->inetref))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->lastModified = (time_t)tmpi;
  ++i;
  if (!ReadField(program->stars))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_time(field.c_str(), &(program->airdate)))
    goto out;
  ++i;
  if (!ReadField(program->recording.playGroup))
    goto out;
  ++i;
  if (!ReadField(field)) // recpriority2
    goto out;
  ++i;
  if (!ReadField(field)) // parentid
    goto out;
  ++i;
  if (!ReadField(program->recording.storageGroup))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->audioProps)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->videoProps)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->subProps)))
    goto out;
  ++i;
  if (!ReadField(field)) // year
    goto out;
  ++i;
  if (!ReadField(field)) // part number
    goto out;
  ++i;
  if (!ReadField(field)) // part total
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->catType = CategoryTypeToString(m_protoVersion, CategoryTypeFromNum(m_protoVersion, (int)tmpi));
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->recording.recordedId)))
    goto out;
  return program;
out:
  DBG(MYTH_DBG_ERROR, "%s: failed (%d) buf='%s'\n", __FUNCTION__, i, field.c_str());
  program.reset();
  return program;
}

ProgramPtr ProtoBase::RcvProgramInfo86()
{
  int64_t tmpi;
  std::string field;
  ProgramPtr program(new Program());
  int i = 0;

  ++i;
  if (!ReadField(program->title))
    goto out;
  ++i;
  if (!ReadField(program->subTitle))
    goto out;
  ++i;
  if (!ReadField(program->description))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->season)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->episode)))
    goto out;
  ++i;
  if (!ReadField(field)) // total episodes
    goto out;
  ++i;
  if (!ReadField(field)) // syndicated episode
    goto out;
  ++i;
  if (!ReadField(program->category))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->channel.chanId)))
    goto out;
  ++i;
  if (!ReadField(program->channel.chanNum))
    goto out;
  ++i;
  if (!ReadField(program->channel.callSign))
    goto out;
  ++i;
  if (!ReadField(program->channel.channelName))
    goto out;
  ++i;
  if (!ReadField(program->fileName))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &(program->fileSize)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->startTime = (time_t)tmpi;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->endTime = (time_t)tmpi;
  ++i;
  if (!ReadField(field)) // findid
    goto out;
  ++i;
  if (!ReadField(program->hostName))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->channel.sourceId)))
    goto out;
  ++i;
  if (!ReadField(field)) // cardid
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->channel.inputId)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int32(field.c_str(), &(program->recording.priority)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int8(field.c_str(), &(program->recording.status)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->recording.recordId)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint8(field.c_str(), &(program->recording.recType)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint8(field.c_str(), &(program->recording.dupInType)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint8(field.c_str(), &(program->recording.dupMethod)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->recording.startTs = (time_t)tmpi;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->recording.endTs = (time_t)tmpi;
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->programFlags)))
    goto out;
  ++i;
  if (!ReadField(program->recording.recGroup))
    goto out;
  ++i;
  if (!ReadField(program->channel.chanFilters))
    goto out;
  ++i;
  if (!ReadField(program->seriesId))
    goto out;
  ++i;
  if (!ReadField(program->programId))
    goto out;
  ++i;
  if (!ReadField(program->inetref))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->lastModified = (time_t)tmpi;
  ++i;
  if (!ReadField(program->stars))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_time(field.c_str(), &(program->airdate)))
    goto out;
  ++i;
  if (!ReadField(program->recording.playGroup))
    goto out;
  ++i;
  if (!ReadField(field)) // recpriority2
    goto out;
  ++i;
  if (!ReadField(field)) // parentid
    goto out;
  ++i;
  if (!ReadField(program->recording.storageGroup))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->audioProps)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->videoProps)))
    goto out;
  ++i;
  if (!ReadField(field) || string_to_uint16(field.c_str(), &(program->subProps)))
    goto out;
  ++i;
  if (!ReadField(field)) // year
    goto out;
  ++i;
  if (!ReadField(field)) // part number
    goto out;
  ++i;
  if (!ReadField(field)) // part total
    goto out;
  ++i;
  if (!ReadField(field) || string_to_int64(field.c_str(), &tmpi))
    goto out;
  program->catType = CategoryTypeToString(m_protoVersion, CategoryTypeFromNum(m_protoVersion, (int)tmpi));
  ++i;
  if (!ReadField(field) || string_to_uint32(field.c_str(), &(program->recording.recordedId)))
    goto out;
  ++i;
  if (!ReadField(field)) // inputname
    goto out;
  ++i;
  if (!ReadField(field)) // bookmarkupdate
    goto out;
  return program;
out:
  DBG(MYTH_DBG_ERROR, "%s: failed (%d) buf='%s'\n", __FUNCTION__, i, field.c_str());
  program.reset();
  return program;
}

void ProtoBase::MakeProgramInfo75(const Program& program, std::string& msg)
{
  char buf[32];
  msg.clear();

  msg.append(program.title).append(PROTO_STR_SEPARATOR);
  msg.append(program.subTitle).append(PROTO_STR_SEPARATOR);
  msg.append(program.description).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.season, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.episode, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.category).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.channel.chanId, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.channel.chanNum).append(PROTO_STR_SEPARATOR);
  msg.append(program.channel.callSign).append(PROTO_STR_SEPARATOR);
  msg.append(program.channel.channelName).append(PROTO_STR_SEPARATOR);
  msg.append(program.fileName).append(PROTO_STR_SEPARATOR);
  int64_to_string(program.fileSize, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.startTime, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.endTime, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // findid
  msg.append(program.hostName).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.channel.sourceId, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // cardid
  uint32_to_string(program.channel.inputId, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int32_to_string(program.recording.priority, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int8_to_string(program.recording.status, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.recording.recordId, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint8_to_string(program.recording.recType, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint8_to_string(program.recording.dupInType, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint8_to_string(program.recording.dupMethod, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.recording.startTs, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.recording.endTs, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.programFlags, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.recording.recGroup).append(PROTO_STR_SEPARATOR);
  msg.append(program.channel.chanFilters).append(PROTO_STR_SEPARATOR);
  msg.append(program.seriesId).append(PROTO_STR_SEPARATOR);
  msg.append(program.programId).append(PROTO_STR_SEPARATOR);
  msg.append(program.inetref).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.lastModified, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.stars).append(PROTO_STR_SEPARATOR);
  time_to_isodate(program.airdate, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.recording.playGroup).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // recpriority2
  msg.append("0").append(PROTO_STR_SEPARATOR); // parentid
  msg.append(program.recording.storageGroup).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.audioProps, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.videoProps, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.subProps, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append("0"); // year
}

void ProtoBase::MakeProgramInfo76(const Program& program, std::string& msg)
{
  char buf[32];
  msg.clear();

  msg.append(program.title).append(PROTO_STR_SEPARATOR);
  msg.append(program.subTitle).append(PROTO_STR_SEPARATOR);
  msg.append(program.description).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.season, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.episode, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(PROTO_STR_SEPARATOR); // syndicated episode
  msg.append(program.category).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.channel.chanId, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.channel.chanNum).append(PROTO_STR_SEPARATOR);
  msg.append(program.channel.callSign).append(PROTO_STR_SEPARATOR);
  msg.append(program.channel.channelName).append(PROTO_STR_SEPARATOR);
  msg.append(program.fileName).append(PROTO_STR_SEPARATOR);
  int64_to_string(program.fileSize, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.startTime, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.endTime, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // findid
  msg.append(program.hostName).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.channel.sourceId, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // cardid
  uint32_to_string(program.channel.inputId, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int32_to_string(program.recording.priority, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int8_to_string(program.recording.status, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.recording.recordId, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint8_to_string(program.recording.recType, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint8_to_string(program.recording.dupInType, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint8_to_string(program.recording.dupMethod, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.recording.startTs, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.recording.endTs, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.programFlags, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.recording.recGroup).append(PROTO_STR_SEPARATOR);
  msg.append(program.channel.chanFilters).append(PROTO_STR_SEPARATOR);
  msg.append(program.seriesId).append(PROTO_STR_SEPARATOR);
  msg.append(program.programId).append(PROTO_STR_SEPARATOR);
  msg.append(program.inetref).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.lastModified, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.stars).append(PROTO_STR_SEPARATOR);
  time_to_isodate(program.airdate, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.recording.playGroup).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // recpriority2
  msg.append("0").append(PROTO_STR_SEPARATOR); // parentid
  msg.append(program.recording.storageGroup).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.audioProps, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.videoProps, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.subProps, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // year
  msg.append("0").append(PROTO_STR_SEPARATOR); // part number
  msg.append("0"); // part total
}

void ProtoBase::MakeProgramInfo79(const Program& program, std::string& msg)
{
  char buf[32];
  msg.clear();

  msg.append(program.title).append(PROTO_STR_SEPARATOR);
  msg.append(program.subTitle).append(PROTO_STR_SEPARATOR);
  msg.append(program.description).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.season, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.episode, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // total episodes
  msg.append(PROTO_STR_SEPARATOR); // syndicated episode
  msg.append(program.category).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.channel.chanId, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.channel.chanNum).append(PROTO_STR_SEPARATOR);
  msg.append(program.channel.callSign).append(PROTO_STR_SEPARATOR);
  msg.append(program.channel.channelName).append(PROTO_STR_SEPARATOR);
  msg.append(program.fileName).append(PROTO_STR_SEPARATOR);
  int64_to_string(program.fileSize, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.startTime, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.endTime, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // findid
  msg.append(program.hostName).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.channel.sourceId, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // cardid
  uint32_to_string(program.channel.inputId, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int32_to_string(program.recording.priority, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int8_to_string(program.recording.status, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.recording.recordId, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint8_to_string(program.recording.recType, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint8_to_string(program.recording.dupInType, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint8_to_string(program.recording.dupMethod, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.recording.startTs, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.recording.endTs, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.programFlags, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.recording.recGroup).append(PROTO_STR_SEPARATOR);
  msg.append(program.channel.chanFilters).append(PROTO_STR_SEPARATOR);
  msg.append(program.seriesId).append(PROTO_STR_SEPARATOR);
  msg.append(program.programId).append(PROTO_STR_SEPARATOR);
  msg.append(program.inetref).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.lastModified, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.stars).append(PROTO_STR_SEPARATOR);
  time_to_isodate(program.airdate, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.recording.playGroup).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // recpriority2
  msg.append("0").append(PROTO_STR_SEPARATOR); // parentid
  msg.append(program.recording.storageGroup).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.audioProps, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.videoProps, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.subProps, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // year
  msg.append("0").append(PROTO_STR_SEPARATOR); // part number
  msg.append("0").append(PROTO_STR_SEPARATOR); // part total
  uint8_to_string((uint8_t)CategoryTypeToNum(m_protoVersion, CategoryTypeFromString(m_protoVersion, program.catType)), buf);
  msg.append(buf);
}

void ProtoBase::MakeProgramInfo82(const Program& program, std::string& msg)
{
  char buf[32];
  msg.clear();

  msg.append(program.title).append(PROTO_STR_SEPARATOR);
  msg.append(program.subTitle).append(PROTO_STR_SEPARATOR);
  msg.append(program.description).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.season, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.episode, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // total episodes
  msg.append(PROTO_STR_SEPARATOR); // syndicated episode
  msg.append(program.category).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.channel.chanId, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.channel.chanNum).append(PROTO_STR_SEPARATOR);
  msg.append(program.channel.callSign).append(PROTO_STR_SEPARATOR);
  msg.append(program.channel.channelName).append(PROTO_STR_SEPARATOR);
  msg.append(program.fileName).append(PROTO_STR_SEPARATOR);
  int64_to_string(program.fileSize, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.startTime, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.endTime, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // findid
  msg.append(program.hostName).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.channel.sourceId, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // cardid
  uint32_to_string(program.channel.inputId, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int32_to_string(program.recording.priority, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int8_to_string(program.recording.status, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.recording.recordId, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint8_to_string(program.recording.recType, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint8_to_string(program.recording.dupInType, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint8_to_string(program.recording.dupMethod, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.recording.startTs, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.recording.endTs, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.programFlags, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.recording.recGroup).append(PROTO_STR_SEPARATOR);
  msg.append(program.channel.chanFilters).append(PROTO_STR_SEPARATOR);
  msg.append(program.seriesId).append(PROTO_STR_SEPARATOR);
  msg.append(program.programId).append(PROTO_STR_SEPARATOR);
  msg.append(program.inetref).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.lastModified, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.stars).append(PROTO_STR_SEPARATOR);
  time_to_isodate(program.airdate, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.recording.playGroup).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // recpriority2
  msg.append("0").append(PROTO_STR_SEPARATOR); // parentid
  msg.append(program.recording.storageGroup).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.audioProps, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.videoProps, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.subProps, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // year
  msg.append("0").append(PROTO_STR_SEPARATOR); // part number
  msg.append("0").append(PROTO_STR_SEPARATOR); // part total
  uint8_to_string((uint8_t)CategoryTypeToNum(m_protoVersion, CategoryTypeFromString(m_protoVersion, program.catType)), buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.recording.recordedId, buf);
  msg.append(buf);
}

void ProtoBase::MakeProgramInfo86(const Program& program, std::string& msg)
{
  char buf[32];
  msg.clear();

  msg.append(program.title).append(PROTO_STR_SEPARATOR);
  msg.append(program.subTitle).append(PROTO_STR_SEPARATOR);
  msg.append(program.description).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.season, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.episode, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // total episodes
  msg.append(PROTO_STR_SEPARATOR); // syndicated episode
  msg.append(program.category).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.channel.chanId, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.channel.chanNum).append(PROTO_STR_SEPARATOR);
  msg.append(program.channel.callSign).append(PROTO_STR_SEPARATOR);
  msg.append(program.channel.channelName).append(PROTO_STR_SEPARATOR);
  msg.append(program.fileName).append(PROTO_STR_SEPARATOR);
  int64_to_string(program.fileSize, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.startTime, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.endTime, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // findid
  msg.append(program.hostName).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.channel.sourceId, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // cardid
  uint32_to_string(program.channel.inputId, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int32_to_string(program.recording.priority, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int8_to_string(program.recording.status, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.recording.recordId, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint8_to_string(program.recording.recType, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint8_to_string(program.recording.dupInType, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint8_to_string(program.recording.dupMethod, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.recording.startTs, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.recording.endTs, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.programFlags, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.recording.recGroup).append(PROTO_STR_SEPARATOR);
  msg.append(program.channel.chanFilters).append(PROTO_STR_SEPARATOR);
  msg.append(program.seriesId).append(PROTO_STR_SEPARATOR);
  msg.append(program.programId).append(PROTO_STR_SEPARATOR);
  msg.append(program.inetref).append(PROTO_STR_SEPARATOR);
  int64_to_string((int64_t)program.lastModified, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.stars).append(PROTO_STR_SEPARATOR);
  time_to_isodate(program.airdate, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append(program.recording.playGroup).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // recpriority2
  msg.append("0").append(PROTO_STR_SEPARATOR); // parentid
  msg.append(program.recording.storageGroup).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.audioProps, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.videoProps, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint16_to_string(program.subProps, buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  msg.append("0").append(PROTO_STR_SEPARATOR); // year
  msg.append("0").append(PROTO_STR_SEPARATOR); // part number
  msg.append("0").append(PROTO_STR_SEPARATOR); // part total
  uint8_to_string((uint8_t)CategoryTypeToNum(m_protoVersion, CategoryTypeFromString(m_protoVersion, program.catType)), buf);
  msg.append(buf).append(PROTO_STR_SEPARATOR);
  uint32_to_string(program.recording.recordedId, buf);
  msg.append(buf);
  msg.append(PROTO_STR_SEPARATOR); // inputname
  msg.append(PROTO_STR_SEPARATOR); // bookmarkupdate
}
