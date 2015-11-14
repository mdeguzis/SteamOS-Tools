#pragma once
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

#include <mythtypes.h>

class MythRecordingRule
{

public:

  MythRecordingRule();
  MythRecordingRule(Myth::RecordSchedulePtr recordschedule);

  Myth::RecordSchedulePtr GetPtr();
  MythRecordingRule DuplicateRecordingRule() const;

  uint32_t RecordID() const;
  void SetRecordID(uint32_t recordid);

  uint32_t ChannelID() const;
  void SetChannelID(uint32_t channelid);

  std::string Callsign() const;
  void SetCallsign(const std::string& callsign);

  time_t StartTime() const;
  void SetStartTime(time_t starttime);

  time_t EndTime() const;
  void SetEndTime(time_t endtime);

  std::string Title() const;
  void SetTitle(const std::string& title);

  std::string Subtitle() const;
  void SetSubtitle(const std::string& subtitle);

  std::string Description() const;
  void SetDescription(const std::string& description);

  Myth::RT_t Type() const;
  void SetType(Myth::RT_t type);

  std::string Category() const;
  void SetCategory(const std::string& category);

  uint8_t StartOffset() const;
  void SetStartOffset(uint8_t startoffset);

  uint8_t EndOffset() const;
  void SetEndOffset(uint8_t endoffset);

  int8_t Priority() const;
  void SetPriority(int8_t priority);

  bool Inactive() const;
  void SetInactive(bool inactive);

  Myth::ST_t SearchType() const;
  void SetSearchType(Myth::ST_t searchtype);

  Myth::DM_t DuplicateControlMethod() const;
  void SetDuplicateControlMethod(Myth::DM_t method);

  Myth::DI_t CheckDuplicatesInType() const;
  void SetCheckDuplicatesInType(Myth::DI_t in);

  std::string RecordingGroup() const;
  void SetRecordingGroup(const std::string& group);

  std::string StorageGroup() const;
  void SetStorageGroup(const std::string& group);

  std::string PlaybackGroup() const;
  void SetPlaybackGroup(const std::string& group);

  bool AutoTranscode() const;
  void SetAutoTranscode(bool enable);

  bool UserJob(int jobnumber) const;
  void SetUserJob(int jobnumber, bool enable);

  bool AutoMetadata() const;
  void SetAutoMetadata(bool enable);

  bool AutoCommFlag() const;
  void SetAutoCommFlag(bool enable);

  bool AutoExpire() const;
  void SetAutoExpire(bool enable);

  uint32_t MaxEpisodes() const;
  void SetMaxEpisodes(uint32_t max);

  bool NewExpiresOldRecord() const;
  void SetNewExpiresOldRecord(bool enable);

  uint32_t Transcoder() const;
  void SetTranscoder(uint32_t transcoder);

  uint32_t ParentID() const;
  void SetParentID(uint32_t parentid);

  uint32_t Filter() const;
  void SetFilter(uint32_t filter);

  std::string ProgramID() const;
  void SetProgramID(const std::string& programid);

  std::string SeriesID() const;
  void SetSeriesID(const std::string& seriesid);

  std::string RecordingProfile() const;
  void SetRecordingProfile(const std::string& profile);

  std::string InetRef() const;
  void SetInerRef(const std::string& inetref);

  uint16_t Season() const;
  void SetSeason(uint16_t season);

  uint16_t Episode() const;
  void SetEpisode(uint16_t episode);

private:
  Myth::RecordSchedulePtr m_recordSchedule;
};
