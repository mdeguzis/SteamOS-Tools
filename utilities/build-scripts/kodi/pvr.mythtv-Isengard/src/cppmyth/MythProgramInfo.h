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

class MythProgramInfo;
typedef std::map<std::string, MythProgramInfo> ProgramInfoMap;

class MythProgramInfo
{
public:
  typedef Myth::RS_t RecordStatus;

  MythProgramInfo();
  MythProgramInfo(Myth::ProgramPtr proginfo);

  bool IsNull() const;
  Myth::ProgramPtr GetPtr() const;
  bool operator ==(const MythProgramInfo &other);
  bool operator !=(const MythProgramInfo &other);

  /// Reset custom flags and properties
  void ResetProps() {  m_flags = 0; m_props.reset(new Props()); }
  /// Copy reference of properties from other
  void CopyProps(const MythProgramInfo &other) { m_props = other.m_props; }
  // Custom flags
  bool IsVisible() const;
  bool IsDeleted() const;
  bool IsLiveTV() const;
  bool HasCoverart() const;
  bool HasFanart() const;
  // Custom props
  void SetPropsVideoFrameRate(float fps);
  float GetPropsVideoFrameRate() const;
  void SetPropsVideoAspec(float aspec);
  float GetPropsVideoAspec() const;
  void SetPropsSerie(bool flag);
  bool GetPropsSerie() const;
  // Program fields
  std::string UID() const;
  std::string ProgramID() const;
  std::string SerieID() const;
  std::string Title() const;
  std::string Subtitle() const;
  std::string HostName() const;
  std::string FileName() const;
  std::string Description() const;
  int Duration() const;
  std::string Category() const;
  time_t StartTime() const;
  time_t EndTime() const;
  bool IsWatched() const;
  bool IsDeletePending() const;
  bool HasBookmark() const;
  uint32_t ChannelID() const;
  std::string ChannelName() const;
  std::string Callsign() const;
  RecordStatus Status() const;
  std::string RecordingGroup() const;
  uint32_t RecordID() const;
  time_t RecordingStartTime() const;
  time_t RecordingEndTime() const;
  int Priority() const;
  std::string StorageGroup() const;
  std::string Inetref() const;
  uint16_t Season() const;
  uint16_t Episode() const;

private:
  Myth::ProgramPtr m_proginfo;
  mutable int32_t m_flags;

  class Props
  {
  public:
    Props()
    : m_videoFrameRate(0)
    , m_videoAspec(0)
    , m_serie(false)
    {}
    ~Props() {}

    float m_videoFrameRate;
    float m_videoAspec;
    bool m_serie;               ///< true if program is serie else false
  };
  MYTH_SHARED_PTR<Props> m_props;

  bool IsSetup() const;
};
