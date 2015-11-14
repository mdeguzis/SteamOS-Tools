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

#include "mythprotorecorder.h"
#include "../mythdebug.h"
#include "../private/os/threads/mutex.h"
#include "../private/builtin.h"


#include <limits>
#include <cstdio>

using namespace Myth;

ProtoRecorder::ProtoRecorder(int num, const std::string& server, unsigned port)
: ProtoPlayback(server, port)
, m_num(num)
, m_playing(false)
, m_liveRecording(false)
{
  ProtoPlayback::Open();
}

ProtoRecorder::~ProtoRecorder()
{
  if (m_playing)
    StopLiveTV();
  ProtoPlayback::Close();
}

int ProtoRecorder::GetNum() const
{
  return m_num;
}

bool ProtoRecorder::IsPlaying() const
{
  return m_playing;
}

bool ProtoRecorder::IsTunable(const Channel& channel)
{
  bool ok = false;
  CardInputListPtr inputlist = GetFreeInputs();
  for (CardInputList::const_iterator it = inputlist->begin(); it != inputlist->end(); ++it)
  {
    const CardInput *input = (*it).get();
    if (input->sourceId != channel.sourceId)
    {
      DBG(MYTH_DBG_DEBUG, "%s: skip input, source id differs (channel: %" PRIu32 ", input: %" PRIu32 ")\n",
              __FUNCTION__, channel.sourceId, input->sourceId);
      continue;
    }
    if (input->mplexId && input->mplexId != channel.mplexId)
    {
      DBG(MYTH_DBG_DEBUG, "%s: skip input, multiplex id differs (channel: %" PRIu32 ", input: %" PRIu32 ")\n",
              __FUNCTION__, channel.mplexId, input->mplexId);
      continue;
    }
    DBG(MYTH_DBG_DEBUG,"%s: using recorder, input is tunable: source id: %" PRIu32 ", multiplex id: %" PRIu32 ", channel: %" PRIu32 ", input: %" PRIu32 ")\n",
            __FUNCTION__, channel.sourceId, channel.mplexId, channel.chanId, input->inputId);
    ok = true;
    break;
  }
  if (!ok)
  {
    DBG(MYTH_DBG_INFO,"%s: recorder is not tunable\n", __FUNCTION__);
  }
  return ok;
}

void ProtoRecorder::DoneRecordingCallback()
{
  OS::CLockGuard lock(*m_mutex);
  m_liveRecording = false;
  DBG(MYTH_DBG_DEBUG, "%s: completed\n", __FUNCTION__);
}

bool ProtoRecorder::SpawnLiveTV75(const std::string& chainid, const std::string& channum)
{
  char buf[32];
  std::string field;

  OS::CLockGuard lock(*m_mutex);
  if (!IsOpen())
    return false;
  std::string cmd("QUERY_RECORDER ");
  int32_to_string((int32_t)m_num, buf);
  cmd.append(buf);
  cmd.append(PROTO_STR_SEPARATOR);
  cmd.append("SPAWN_LIVETV");
  cmd.append(PROTO_STR_SEPARATOR);
  cmd.append(chainid);
  cmd.append(PROTO_STR_SEPARATOR).append("0").append(PROTO_STR_SEPARATOR);
  cmd.append(channum);

  DBG(MYTH_DBG_DEBUG, "%s: starting ...\n", __FUNCTION__);
  m_playing = true;
  if (!SendCommand(cmd.c_str()))
  {
    m_playing = false;
  }
  else if (!ReadField(field) || !IsMessageOK(field))
  {
    m_playing = false;
    FlushMessage();
  }
  DBG(MYTH_DBG_DEBUG, "%s: %s\n", __FUNCTION__, (m_playing ? "succeeded" : "failed"));
  return m_playing;
}

bool ProtoRecorder::StopLiveTV75()
{
  char buf[32];
  std::string field;

  OS::CLockGuard lock(*m_mutex);
  if (!IsOpen())
    return false;
  std::string cmd("QUERY_RECORDER ");
  int32_to_string((int32_t)m_num, buf);
  cmd.append(buf);
  cmd.append(PROTO_STR_SEPARATOR);
  cmd.append("STOP_LIVETV");

  if (!SendCommand(cmd.c_str()))
    return false;
  if (!ReadField(field) || !IsMessageOK(field))
  {
      FlushMessage();
      return false;
  }
  m_playing = false;
  return true;
}

bool ProtoRecorder::CheckChannel75(const std::string& channum)
{
  char buf[32];
  std::string field;

  OS::CLockGuard lock(*m_mutex);
  if (!IsOpen())
    return false;
  std::string cmd("QUERY_RECORDER ");
  int32_to_string((int32_t)m_num, buf);
  cmd.append(buf);
  cmd.append(PROTO_STR_SEPARATOR);
  cmd.append("CHECK_CHANNEL");
  cmd.append(PROTO_STR_SEPARATOR);
  cmd.append(channum);

  if (!SendCommand(cmd.c_str()))
    return false;
  if (!ReadField(field) || field != "1")
  {
    DBG(MYTH_DBG_DEBUG, "%s: %s\n", __FUNCTION__, field.c_str());
      FlushMessage();
      return false;
  }
  return true;
}

ProgramPtr ProtoRecorder::GetCurrentRecording75()
{
  char buf[32];
  ProgramPtr program;

  OS::CLockGuard lock(*m_mutex);
  if (!IsOpen())
    return program;
  std::string cmd("QUERY_RECORDER ");
  int32_to_string((int32_t)m_num, buf);
  cmd.append(buf);
  cmd.append(PROTO_STR_SEPARATOR);
  cmd.append("GET_CURRENT_RECORDING");

  if (!SendCommand(cmd.c_str()))
    return program;

  if (!(program = RcvProgramInfo()))
    goto out;
  FlushMessage();
  return program;
out:
  DBG(MYTH_DBG_ERROR, "%s: failed\n", __FUNCTION__);
  FlushMessage();
  return program;
}

int64_t ProtoRecorder::GetFilePosition75()
{
  char buf[32];
  int64_t pos;
  std::string field;

  OS::CLockGuard lock(*m_mutex);
  if (!IsOpen() || !IsPlaying())
    return -1;
  std::string cmd("QUERY_RECORDER ");
  int32_to_string((int32_t)m_num, buf);
  cmd.append(buf);
  cmd.append(PROTO_STR_SEPARATOR);
  cmd.append("GET_FILE_POSITION");

  if (!SendCommand(cmd.c_str()))
    return -1;

  if (!ReadField(field) || string_to_int64(field.c_str(), &pos))
    goto out;

  FlushMessage();
  return pos;

out:
  FlushMessage();
  return -1;
}

CardInputListPtr ProtoRecorder::GetFreeInputs75()
{
  CardInputListPtr list = CardInputListPtr(new CardInputList());
  char buf[32];
  std::string field;

  OS::CLockGuard lock(*m_mutex);
  if (!IsOpen())
    return list;
  std::string cmd("QUERY_RECORDER ");
  int32_to_string((int32_t)m_num, buf);
  cmd.append(buf);
  cmd.append(PROTO_STR_SEPARATOR);
  cmd.append("GET_FREE_INPUTS");

  if (!SendCommand(cmd.c_str()))
    return list;

  while (m_msgConsumed < m_msgLength)
  {
    CardInputPtr input(new CardInput());
    if (!ReadField(input->inputName))
      break;
    if (!ReadField(field) || string_to_uint32(field.c_str(), &(input->sourceId)))
      break;
    if (!ReadField(field) || string_to_uint32(field.c_str(), &(input->inputId)))
      break;
    if (!ReadField(field) || string_to_uint32(field.c_str(), &(input->cardId)))
      break;
    if (!ReadField(field) || string_to_uint32(field.c_str(), &(input->mplexId)))
      break;
    if (!ReadField(field) || string_to_uint8(field.c_str(), &(input->liveTVOrder)))
      break;
    list->push_back(input);
  }
  FlushMessage();
  return list;
}

CardInputListPtr ProtoRecorder::GetFreeInputs79()
{
  CardInputListPtr list = CardInputListPtr(new CardInputList());
  char buf[32];
  std::string field;

  OS::CLockGuard lock(*m_mutex);
  if (!IsOpen())
    return list;
  std::string cmd("QUERY_RECORDER ");
  int32_to_string((int32_t)m_num, buf);
  cmd.append(buf);
  cmd.append(PROTO_STR_SEPARATOR);
  cmd.append("GET_FREE_INPUTS");

  if (!SendCommand(cmd.c_str()))
    return list;

  while (m_msgConsumed < m_msgLength)
  {
    CardInputPtr input(new CardInput());
    if (!ReadField(input->inputName))
      break;
    if (!ReadField(field) || string_to_uint32(field.c_str(), &(input->sourceId)))
      break;
    if (!ReadField(field) || string_to_uint32(field.c_str(), &(input->inputId)))
      break;
    if (!ReadField(field) || string_to_uint32(field.c_str(), &(input->cardId)))
      break;
    if (!ReadField(field) || string_to_uint32(field.c_str(), &(input->mplexId)))
      break;
    if (!ReadField(field) || string_to_uint8(field.c_str(), &(input->liveTVOrder)))
      break;
    if (!ReadField(field)) // displayName
      break;
    if (!ReadField(field)) // recPriority
      break;
    if (!ReadField(field)) // schedOrder
      break;
    if (!ReadField(field)) // quickTune
      break;
    list->push_back(input);
  }
  FlushMessage();
  return list;
}

CardInputListPtr ProtoRecorder::GetFreeInputs81()
{
  CardInputListPtr list = CardInputListPtr(new CardInputList());
  char buf[32];
  std::string field;

  OS::CLockGuard lock(*m_mutex);
  if (!IsOpen())
    return list;
  std::string cmd("QUERY_RECORDER ");
  int32_to_string((int32_t)m_num, buf);
  cmd.append(buf);
  cmd.append(PROTO_STR_SEPARATOR);
  cmd.append("GET_FREE_INPUTS");

  if (!SendCommand(cmd.c_str()))
    return list;

  while (m_msgConsumed < m_msgLength)
  {
    CardInputPtr input(new CardInput());
    if (!ReadField(input->inputName))
      break;
    if (!ReadField(field) || string_to_uint32(field.c_str(), &(input->sourceId)))
      break;
    if (!ReadField(field) || string_to_uint32(field.c_str(), &(input->inputId)))
      break;
    if (!ReadField(field) || string_to_uint32(field.c_str(), &(input->cardId)))
      break;
    if (!ReadField(field) || string_to_uint32(field.c_str(), &(input->mplexId)))
      break;
    if (!ReadField(field) || string_to_uint8(field.c_str(), &(input->liveTVOrder)))
      break;
    if (!ReadField(field)) // displayName
      break;
    if (!ReadField(field)) // recPriority
      break;
    if (!ReadField(field)) // schedOrder
      break;
    if (!ReadField(field)) // quickTune
      break;
    if (!ReadField(field)) // chanid
      break;
    list->push_back(input);
  }
  FlushMessage();
  return list;
}

CardInputListPtr ProtoRecorder::GetFreeInputs87()
{
  CardInputListPtr list = CardInputListPtr(new CardInputList());
  std::string field;

  OS::CLockGuard lock(*m_mutex);
  if (!IsOpen())
    return list;
  std::string cmd("GET_FREE_INPUT_INFO 0");

  if (!SendCommand(cmd.c_str()))
    return list;

  while (m_msgConsumed < m_msgLength)
  {
    CardInputPtr input(new CardInput());
    if (!ReadField(input->inputName))
      break;
    if (!ReadField(field) || string_to_uint32(field.c_str(), &(input->sourceId)))
      break;
    if (!ReadField(field) || string_to_uint32(field.c_str(), &(input->inputId)))
      break;
    if (!ReadField(field) || string_to_uint32(field.c_str(), &(input->cardId)))
      break;
    if (!ReadField(field) || string_to_uint32(field.c_str(), &(input->mplexId)))
      break;
    if (!ReadField(field) || string_to_uint8(field.c_str(), &(input->liveTVOrder)))
      break;
    if (!ReadField(field)) // displayName
      break;
    if (!ReadField(field)) // recPriority
      break;
    if (!ReadField(field)) // schedOrder
      break;
    if (!ReadField(field)) // quickTune
      break;
    if (!ReadField(field)) // chanid
      break;
    if (input->cardId == static_cast<unsigned>(m_num))
      list->push_back(input);
  }
  FlushMessage();
  return list;
}

bool ProtoRecorder::IsLiveRecording()
{
  OS::CLockGuard lock(*m_mutex);
  return m_liveRecording;
}

bool ProtoRecorder::SetLiveRecording75(bool keep)
{
  char buf[32];
  std::string field;

  OS::CLockGuard lock(*m_mutex);
  if (!IsOpen())
    return false;
  std::string cmd("QUERY_RECORDER ");
  int32_to_string((int32_t)m_num, buf);
  cmd.append(buf);
  cmd.append(PROTO_STR_SEPARATOR);
  cmd.append("SET_LIVE_RECORDING").append(PROTO_STR_SEPARATOR);
  if (keep)
    cmd.append("1");
  else
    cmd.append("0");

  if (!SendCommand(cmd.c_str()))
    return false;

  if (!ReadField(field) || !IsMessageOK(field))
    goto out;
  DBG(MYTH_DBG_DEBUG, "%s: succeeded (%d)\n", __FUNCTION__, keep);
  return true;
out:
  DBG(MYTH_DBG_ERROR, "%s: failed\n", __FUNCTION__);
  FlushMessage();
  return false;
}

bool ProtoRecorder::FinishRecording75()
{
  char buf[32];
  std::string field;

  OS::CLockGuard lock(*m_mutex);
  if (!IsOpen())
    return false;
  std::string cmd("QUERY_RECORDER ");
  int32_to_string((int32_t)m_num, buf);
  cmd.append(buf);
  cmd.append(PROTO_STR_SEPARATOR);
  cmd.append("FINISH_RECORDING");

  if (!SendCommand(cmd.c_str()))
    return false;

  if (!ReadField(field) || !IsMessageOK(field))
    goto out;
  DBG(MYTH_DBG_DEBUG, "%s: succeeded\n", __FUNCTION__);
  return true;
out:
  DBG(MYTH_DBG_ERROR, "%s: failed\n", __FUNCTION__);
  FlushMessage();
  return false;
}
