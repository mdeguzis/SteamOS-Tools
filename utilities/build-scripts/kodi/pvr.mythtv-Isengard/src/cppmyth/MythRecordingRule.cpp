/*
 *      Copyright (C) 2005-2014 Team XBMC
 *      http://www.xbmc.org
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
 *  along with XBMC; see the file COPYING.  If not, see
 *  <http://www.gnu.org/licenses/>.
 *
 */

#include "MythRecordingRule.h"

MythRecordingRule::MythRecordingRule()
: m_recordSchedule(new Myth::RecordSchedule())
{
}

MythRecordingRule::MythRecordingRule(Myth::RecordSchedulePtr recordschedule)
: m_recordSchedule(new Myth::RecordSchedule())
{
  if (recordschedule)
    m_recordSchedule.swap(recordschedule);
}

Myth::RecordSchedulePtr MythRecordingRule::GetPtr()
{
  return m_recordSchedule;
}

MythRecordingRule MythRecordingRule::DuplicateRecordingRule() const
{
  Myth::RecordSchedulePtr copy(new Myth::RecordSchedule());
  *copy = *m_recordSchedule;
  return MythRecordingRule(copy);
}

uint32_t MythRecordingRule::RecordID() const
{
  return m_recordSchedule->recordId;
}

void MythRecordingRule::SetRecordID(uint32_t recordid)
{
  m_recordSchedule->recordId = recordid;
}

uint32_t MythRecordingRule::ChannelID() const
{
  return m_recordSchedule->chanId;
}

void MythRecordingRule::SetChannelID(uint32_t chanid)
{
  m_recordSchedule->chanId = chanid;
}

std::string MythRecordingRule::Callsign() const
{
  return m_recordSchedule->callSign;
}

void MythRecordingRule::SetCallsign(const std::string& channame)
{
  m_recordSchedule->callSign = channame;
}

time_t MythRecordingRule::StartTime() const
{
  return m_recordSchedule->startTime;
}

void MythRecordingRule::SetStartTime(time_t starttime)
{
  m_recordSchedule->startTime = starttime;
}

time_t MythRecordingRule::EndTime() const
{
  return m_recordSchedule->endTime;
}

void MythRecordingRule::SetEndTime(time_t endtime)
{
  m_recordSchedule->endTime = endtime;
}

std::string MythRecordingRule::Title() const
{
  return m_recordSchedule->title;
}

void MythRecordingRule::SetTitle(const std::string& title)
{
  m_recordSchedule->title = title;
}

std::string MythRecordingRule::Subtitle() const
{
  return m_recordSchedule->subtitle;
}

void MythRecordingRule::SetSubtitle(const std::string& subtitle)
{
  m_recordSchedule->subtitle = subtitle;
}

std::string MythRecordingRule::Description() const
{
  return m_recordSchedule->description;
}

void MythRecordingRule::SetDescription(const std::string& description)
{
  m_recordSchedule->description = description;
}

Myth::RT_t MythRecordingRule::Type() const
{
  return m_recordSchedule->type_t;
}

void MythRecordingRule::SetType(Myth::RT_t type)
{
  m_recordSchedule->type_t = type;
}

std::string MythRecordingRule::Category() const
{
  return m_recordSchedule->category;
}

void MythRecordingRule::SetCategory(const std::string& category)
{
  m_recordSchedule->category = category;
}

uint8_t MythRecordingRule::StartOffset() const
{
  return m_recordSchedule->startOffset;
}

void MythRecordingRule::SetStartOffset(uint8_t startoffset)
{
  m_recordSchedule->startOffset = startoffset;
}

uint8_t MythRecordingRule::EndOffset() const
{
  return m_recordSchedule->endOffset;
}

void MythRecordingRule::SetEndOffset(uint8_t endoffset)
{
  m_recordSchedule->endOffset = endoffset;
}

int8_t MythRecordingRule::Priority() const
{
  return m_recordSchedule->recPriority;
}

void MythRecordingRule::SetPriority(int8_t priority)
{
  m_recordSchedule->recPriority = priority;
}

bool MythRecordingRule::Inactive() const
{
  return m_recordSchedule->inactive;
}

void MythRecordingRule::SetInactive(bool inactive)
{
  m_recordSchedule->inactive = inactive;
}

Myth::ST_t MythRecordingRule::SearchType() const
{
  return m_recordSchedule->searchType_t;
}

void MythRecordingRule::SetSearchType(Myth::ST_t searchtype)
{
  m_recordSchedule->searchType_t = searchtype;
}

Myth::DM_t MythRecordingRule::DuplicateControlMethod() const
{
  return m_recordSchedule->dupMethod_t;
}

void MythRecordingRule::SetDuplicateControlMethod(Myth::DM_t method)
{
  m_recordSchedule->dupMethod_t = method;
}

Myth::DI_t MythRecordingRule::CheckDuplicatesInType() const
{
  return m_recordSchedule->dupIn_t;
}

void MythRecordingRule::SetCheckDuplicatesInType(Myth::DI_t in)
{
  m_recordSchedule->dupIn_t = in;
}

std::string MythRecordingRule::RecordingGroup() const
{
  return m_recordSchedule->recGroup;
}

void MythRecordingRule::SetRecordingGroup(const std::string& group)
{
  m_recordSchedule->recGroup = group;
}

std::string MythRecordingRule::StorageGroup() const
{
  return m_recordSchedule->storageGroup;
}

void MythRecordingRule::SetStorageGroup(const std::string& group)
{
  m_recordSchedule->storageGroup = group;
}

std::string  MythRecordingRule::PlaybackGroup() const
{
  return m_recordSchedule->playGroup;
}

void  MythRecordingRule::SetPlaybackGroup(const std::string& group)
{
  m_recordSchedule->playGroup = group;
}

bool  MythRecordingRule::AutoTranscode() const
{
  return m_recordSchedule->autoTranscode;
}

void  MythRecordingRule::SetAutoTranscode(bool enable)
{
  m_recordSchedule->autoTranscode = enable;
}

bool MythRecordingRule::UserJob(int jobnumber) const
{
  switch (jobnumber)
  {
  case 1:
    return m_recordSchedule->autoUserJob1;
  case 2:
    return m_recordSchedule->autoUserJob2;
  case 3:
    return m_recordSchedule->autoUserJob3;
  case 4:
    return m_recordSchedule->autoUserJob4;
  default:
    break;
  }
  return false;
}

void MythRecordingRule::SetUserJob(int jobnumber, bool enable)
{
  switch (jobnumber)
  {
  case 1:
    m_recordSchedule->autoUserJob1 = enable;
    break;
  case 2:
    m_recordSchedule->autoUserJob2 = enable;
    break;
  case 3:
    m_recordSchedule->autoUserJob3 = enable;
    break;
  case 4:
    m_recordSchedule->autoUserJob4 = enable;
    break;
  default:
    break;
  }
}

bool  MythRecordingRule::AutoMetadata() const
{
  return m_recordSchedule->autoMetaLookup;
}

void  MythRecordingRule::SetAutoMetadata(bool enable)
{
  m_recordSchedule->autoMetaLookup = enable;
}

bool  MythRecordingRule::AutoCommFlag() const
{
  return m_recordSchedule->autoCommflag;
}

void  MythRecordingRule::SetAutoCommFlag(bool enable)
{
  m_recordSchedule->autoCommflag = enable;
}

bool  MythRecordingRule::AutoExpire() const
{
  return m_recordSchedule->autoExpire;
}

void  MythRecordingRule::SetAutoExpire(bool enable)
{
  m_recordSchedule->autoExpire = enable;
}

uint32_t MythRecordingRule::MaxEpisodes() const
{
  return m_recordSchedule->maxEpisodes;
}

void  MythRecordingRule::SetMaxEpisodes(uint32_t max)
{
  m_recordSchedule->maxEpisodes = max;
}

bool  MythRecordingRule::NewExpiresOldRecord() const
{
  return m_recordSchedule->maxNewest;
}

void  MythRecordingRule::SetNewExpiresOldRecord(bool enable)
{
  m_recordSchedule->maxNewest = enable;
}

uint32_t MythRecordingRule::Transcoder() const
{
  return m_recordSchedule->transcoder;
}

void MythRecordingRule::SetTranscoder(uint32_t transcoder)
{
  m_recordSchedule->transcoder = transcoder;
}

uint32_t MythRecordingRule::ParentID() const
{
  return m_recordSchedule->parentId;
}

void MythRecordingRule::SetParentID(uint32_t parentid)
{
  m_recordSchedule->parentId = parentid;
}

uint32_t MythRecordingRule::Filter() const
{
  return m_recordSchedule->filter;
}

void MythRecordingRule::SetFilter(uint32_t filter)
{
  m_recordSchedule->filter = filter;
}

std::string MythRecordingRule::ProgramID() const
{
  return m_recordSchedule->programId;
}

void MythRecordingRule::SetProgramID(const std::string& programid)
{
  m_recordSchedule->programId = programid;
}

std::string MythRecordingRule::SeriesID() const
{
  return m_recordSchedule->seriesId;
}

void MythRecordingRule::SetSeriesID(const std::string& seriesid)
{
  m_recordSchedule->seriesId = seriesid;
}

std::string MythRecordingRule::RecordingProfile() const
{
  return m_recordSchedule->recProfile;
}

void MythRecordingRule::SetRecordingProfile(const std::string& profile)
{
  m_recordSchedule->recProfile = profile;
}

std::string MythRecordingRule::InetRef() const
{
  return m_recordSchedule->inetref;
}

void MythRecordingRule::SetInerRef(const std::string& inetref)
{
  m_recordSchedule->inetref = inetref;
}

uint16_t MythRecordingRule::Season() const
{
  return m_recordSchedule->season;
}

void MythRecordingRule::SetSeason(uint16_t season)
{
  m_recordSchedule->season = season;
}

uint16_t MythRecordingRule::Episode() const
{
  return m_recordSchedule->episode;
}

void MythRecordingRule::SetEpisode(uint16_t episode)
{
  m_recordSchedule->episode = episode;
}
