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

#include "mythprotoevent.h"
#include "../mythdebug.h"
#include "../private/mythsocket.h"
#include "../private/os/threads/mutex.h"
#include "../private/builtin.h"

#include <limits>
#include <cstdio>
#include <vector>

using namespace Myth;

void __tokenize(const std::string& str, const char *delimiters, std::vector<std::string>& tokens, bool trimnull = false)
{
  std::string::size_type pa = 0, pb = 0;
  unsigned n = 0;
  // Counter n will break infinite loop. Max count is 255 tokens
  while ((pb = str.find_first_of(delimiters, pb)) != std::string::npos && ++n < 255)
  {
    tokens.push_back(str.substr(pa, pb - pa));
    do
    {
      pa = ++pb;
    }
    while (trimnull && str.find_first_of(delimiters, pb) == pb);
  }
  tokens.push_back(str.substr(pa));
}

///////////////////////////////////////////////////////////////////////////////
////
//// Protocol connection to listen event
////

ProtoEvent::ProtoEvent(const std::string& server, unsigned port)
: ProtoBase(server, port)
{
}

bool ProtoEvent::Open()
{
  bool ok = false;

  if (!OpenConnection(PROTO_EVENT_RCVBUF))
    return false;

  if (m_protoVersion >= 75)
    ok = Announce75();

  if (ok)
    return true;
  Close();
  return false;
}

void ProtoEvent::Close()
{
  ProtoBase::Close();
  // Clean hanging and disable retry
  m_tainted = m_hang = false;
}

bool ProtoEvent::Announce75()
{
  OS::CLockGuard lock(*m_mutex);

  std::string cmd("ANN Monitor ");
  cmd.append(m_socket->GetMyHostName()).append(" 1");
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

SignalStatusPtr ProtoEvent::RcvSignalStatus()
{
  SignalStatusPtr signal(new SignalStatus()); // Using default constructor
  std::string field;
  while (ReadField(field))
  {
    std::vector<std::string> tokens;
    // Tokenize the content
    __tokenize(field, " ", tokens, false);
    // Fill my signal
    if (tokens.size() > 1)
    {
      int64_t tmpi;
      if (tokens[0] == "slock")
        signal->lock = (tokens[1] == "1" ? true : false);
      else if (tokens[0] == "signal")
        signal->signal = (0 == string_to_int64(tokens[1].c_str(), &tmpi) ? (int)tmpi : 0);
      else if (tokens[0] == "snr")
        signal->snr = (0 == string_to_int64(tokens[1].c_str(), &tmpi) ? (int)tmpi : 0);
      else if (tokens[0] == "ber")
        signal->ber = (0 == string_to_int64(tokens[1].c_str(), &tmpi) ? (long)tmpi : 0);
      else if (tokens[0] == "ucb")
        signal->ucb = (0 == string_to_int64(tokens[1].c_str(), &tmpi) ? (long)tmpi : 0);
    }
  }
  return signal;
}

int ProtoEvent::RcvBackendMessage(unsigned timeout, EventMessage& msg)
{
  OS::CLockGuard lock(*m_mutex);
  struct timeval tv;
  tv.tv_sec = timeout;
  tv.tv_usec = 0;
  int r = m_socket->Listen(&tv);
  if (r > 0)
  {
    std::string field;
    msg.event = EVENT_UNKNOWN;
    msg.subject.clear();
    msg.program.reset();
    msg.signal.reset();
    if (RcvMessageLength() && ReadField(field) && field == "BACKEND_MESSAGE")
    {
      unsigned n = 0;
      ReadField(field);
      // Tokenize the subject
      __tokenize(field, " ", msg.subject, false);
      n = (unsigned)msg.subject.size();
      DBG(MYTH_DBG_DEBUG, "%s: %s (%u)\n", __FUNCTION__, field.c_str(), n);

      if (msg.subject[0] == "UPDATE_FILE_SIZE")
        msg.event = EVENT_UPDATE_FILE_SIZE;
      else if (msg.subject[0] == "DONE_RECORDING")
        msg.event = EVENT_DONE_RECORDING;
      else if (msg.subject[0] == "QUIT_LIVETV")
        msg.event = EVENT_QUIT_LIVETV;
      else if (msg.subject[0] == "LIVETV_WATCH")
        msg.event = EVENT_LIVETV_WATCH;
      else if (msg.subject[0] == "LIVETV_CHAIN")
        msg.event = EVENT_LIVETV_CHAIN;
      else if (msg.subject[0] == "SIGNAL")
      {
        msg.event = EVENT_SIGNAL;
        msg.signal = RcvSignalStatus();
      }
      else if (msg.subject[0] == "RECORDING_LIST_CHANGE")
      {
        msg.event = EVENT_RECORDING_LIST_CHANGE;
        if (n > 1 && msg.subject[1] == "UPDATE")
          msg.program = RcvProgramInfo();
      }
      else if (msg.subject[0] == "SCHEDULE_CHANGE")
        msg.event = EVENT_SCHEDULE_CHANGE;
      else if (msg.subject[0] == "ASK_RECORDING")
      {
        msg.event = EVENT_ASK_RECORDING;
        msg.program = RcvProgramInfo();
      }
      else if (msg.subject[0] == "CLEAR_SETTINGS_CACHE")
        msg.event = EVENT_CLEAR_SETTINGS_CACHE;
      else if (msg.subject[0] == "GENERATED_PIXMAP")
        msg.event = EVENT_GENERATED_PIXMAP;
      else if (msg.subject[0] == "SYSTEM_EVENT")
        msg.event = EVENT_SYSTEM_EVENT;
      else
        msg.event = EVENT_UNKNOWN;
    }

    FlushMessage();
    return (m_hang ? -(ENOTCONN) : 1);
  }
  else if (r < 0)
    return r;

  return ((ProtoBase::IsOpen() && !m_hang) ? 0 : -(ENOTCONN));
}
