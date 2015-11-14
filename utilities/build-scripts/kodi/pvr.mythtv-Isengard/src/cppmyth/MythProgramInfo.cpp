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

#include "MythProgramInfo.h"

#include <cstdio> // for sprintf
#include <time.h> // for difftime

enum
{
  FLAGS_INITIALIZED   = 0x80000000,
  FLAGS_HAS_COVERART  = 0x00000001,
  FLAGS_HAS_FANART    = 0x00000002,
  FLAGS_HAS_BANNER    = 0x00000004,
  FLAGS_IS_VISIBLE    = 0x00000008,
  FLAGS_IS_LIVETV     = 0x00000010,
  FLAGS_IS_DELETED    = 0x00000020,
};

MythProgramInfo::MythProgramInfo()
: m_proginfo()
, m_flags(0)
, m_props(new Props())
{
}

MythProgramInfo::MythProgramInfo(Myth::ProgramPtr proginfo)
: m_proginfo()
, m_flags(0)
, m_props(new Props())
{
  m_proginfo.swap(proginfo);
}

bool MythProgramInfo::IsNull() const
{
  if (!m_proginfo)
    return true;
  return m_proginfo.get() == NULL;
}

Myth::ProgramPtr MythProgramInfo::GetPtr() const
{
  return m_proginfo;
}

bool MythProgramInfo::operator ==(const MythProgramInfo &other)
{
  if (!this->IsNull() && !other.IsNull())
  {
    if (this->m_proginfo->channel.chanId == other.m_proginfo->channel.chanId &&
            this->m_proginfo->recording.startTs == other.m_proginfo->recording.startTs)
      return true;
  }
  return false;
}

bool MythProgramInfo::operator !=(const MythProgramInfo &other)
{
  return !(*this == other);
}

bool MythProgramInfo::IsSetup() const
{
  if (m_flags)
    return true;

  m_flags |= FLAGS_INITIALIZED;

  if (m_proginfo)
  {
    // Has Artworks ?
    for (std::vector<Myth::Artwork>::const_iterator it = m_proginfo->artwork.begin(); it != m_proginfo->artwork.end(); ++it)
    {
      if (it->type == "coverart")
        m_flags |= FLAGS_HAS_COVERART;
      else if (it->type == "fanart")
        m_flags |= FLAGS_HAS_FANART;
      else if (it->type == "banner")
        m_flags |= FLAGS_HAS_BANNER;
    }

    // Is Visible ?
    // Filter out recording of special storage group Deleted
    // Filter out recording with duration less than 5 seconds
    // When  deleting a recording, it might not be deleted immediately but marked as 'pending delete'.
    // Depending on the protocol version the recording is moved to the group Deleted or
    // the 'delete pending' flag is set
    if (Duration() >= 5)
    {
      if (RecordingGroup() == "Deleted" || IsDeletePending())
        m_flags |= FLAGS_IS_DELETED;
      else
        m_flags |= FLAGS_IS_VISIBLE;
    }

    // Is LiveTV ?
    if (RecordingGroup() == "LiveTV")
      m_flags |= FLAGS_IS_LIVETV;
  }
  return true;
}

bool MythProgramInfo::IsVisible() const
{
  if (IsSetup() && (m_flags & FLAGS_IS_VISIBLE))
    return true;
  return false;
}

bool MythProgramInfo::IsDeleted() const
{
  if (IsSetup() && (m_flags & FLAGS_IS_DELETED))
    return true;
  return false;
}

bool MythProgramInfo::IsLiveTV() const
{
  if (IsSetup() && (m_flags & FLAGS_IS_LIVETV))
    return true;
  return false;
}

bool MythProgramInfo::HasCoverart() const
{
  if (IsSetup() && (m_flags & FLAGS_HAS_COVERART))
    return true;
  return false;
}

bool MythProgramInfo::HasFanart() const
{
  if (IsSetup() && (m_flags & FLAGS_HAS_FANART))
    return true;
  return false;
}

void MythProgramInfo::SetPropsVideoFrameRate(float fps)
{
  m_props->m_videoFrameRate = fps;
}

float MythProgramInfo::GetPropsVideoFrameRate() const
{
  return m_props->m_videoFrameRate;
}

void MythProgramInfo::SetPropsVideoAspec(float aspec)
{
  m_props->m_videoAspec = aspec;
}

float MythProgramInfo::GetPropsVideoAspec() const
{
  return m_props->m_videoAspec;
}

void MythProgramInfo::SetPropsSerie(bool flag)
{
  m_props->m_serie = flag;
}

bool MythProgramInfo::GetPropsSerie() const
{
  return m_props->m_serie;
}

std::string MythProgramInfo::UID() const
{
  char buf[48] = "";
  sprintf(buf, "%u_%ld_%.3x",
          (unsigned)m_proginfo->channel.chanId,
          (long)m_proginfo->recording.startTs,
          (unsigned)m_proginfo->recording.recordedId & 0xfff);
  return std::string(buf);
}

std::string MythProgramInfo::ProgramID() const
{
  return (m_proginfo ? m_proginfo->programId : "");
}

std::string MythProgramInfo::SerieID() const
{
  return (m_proginfo ? m_proginfo->seriesId : "");
}

std::string MythProgramInfo::Title() const
{
  return (m_proginfo ? m_proginfo->title : "");
}

std::string MythProgramInfo::Subtitle() const
{
  return (m_proginfo ? m_proginfo->subTitle : "");
}

std::string MythProgramInfo::HostName() const
{
  return (m_proginfo ? m_proginfo->hostName : "");
}

std::string MythProgramInfo::FileName() const
{
  return (m_proginfo ? m_proginfo->fileName : "");
}

std::string MythProgramInfo::Description() const
{
  return (m_proginfo ? m_proginfo->description : "");
}

int MythProgramInfo::Duration() const
{
  return (m_proginfo ? (int)difftime(m_proginfo->recording.endTs, m_proginfo->recording.startTs) : 0);
}

std::string MythProgramInfo::Category() const
{
  return (m_proginfo ? m_proginfo->category : "");
}

time_t MythProgramInfo::StartTime() const
{
  return (m_proginfo ? m_proginfo->startTime : (time_t)(-1));
}

time_t MythProgramInfo::EndTime() const
{
  return (m_proginfo ? m_proginfo->endTime : (time_t)(-1));
}

bool MythProgramInfo::IsWatched() const
{
  return ((m_proginfo && (m_proginfo->programFlags & 0x00000200)) ? true : false);
}

bool MythProgramInfo::IsDeletePending() const
{
  return ((m_proginfo && (m_proginfo->programFlags & 0x00000080)) ? true : false);
}

bool MythProgramInfo::HasBookmark() const
{
  return ((m_proginfo && (m_proginfo->programFlags & 0x00000010)) ? true : false);
}

uint32_t MythProgramInfo::ChannelID() const
{
  return (m_proginfo ? m_proginfo->channel.chanId : 0);
}

std::string MythProgramInfo::ChannelName() const
{
  return (m_proginfo ? m_proginfo->channel.channelName : "");
}

std::string MythProgramInfo::Callsign() const
{
  return (m_proginfo ? m_proginfo->channel.callSign : "");
}


MythProgramInfo::RecordStatus MythProgramInfo::Status() const
{
  return (m_proginfo ? (RecordStatus)m_proginfo->recording.status : Myth::RS_UNKNOWN);
}

std::string MythProgramInfo::RecordingGroup() const
{
  return (m_proginfo ? m_proginfo->recording.recGroup : "");
}

uint32_t MythProgramInfo::RecordID() const
{
  return (m_proginfo ? m_proginfo->recording.recordId : 0);
}

time_t MythProgramInfo::RecordingStartTime() const
{
  return (m_proginfo ? m_proginfo->recording.startTs : (time_t)(-1));
}

time_t MythProgramInfo::RecordingEndTime() const
{
  return (m_proginfo ? m_proginfo->recording.endTs : (time_t)(-1));
}

int MythProgramInfo::Priority() const
{
  return (m_proginfo ? m_proginfo->recording.priority : 0);
}

std::string MythProgramInfo::StorageGroup() const
{
  return (m_proginfo ? m_proginfo->recording.storageGroup : "");
}

std::string MythProgramInfo::Inetref() const
{
  return (m_proginfo ? m_proginfo->inetref : "");
}

uint16_t MythProgramInfo::Season() const
{
  return (m_proginfo ? m_proginfo->season : 0);
}

uint16_t MythProgramInfo::Episode() const
{
  return (m_proginfo ? m_proginfo->episode : 0);
}
