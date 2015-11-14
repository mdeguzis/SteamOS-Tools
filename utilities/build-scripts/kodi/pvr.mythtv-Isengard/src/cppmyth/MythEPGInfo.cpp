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

#include "MythEPGInfo.h"
#include "../tools.h"

MythEPGInfo::MythEPGInfo()
  : m_epginfo()
{
}

MythEPGInfo::MythEPGInfo(Myth::ProgramPtr epginfo)
  : m_epginfo()
{
  m_epginfo.swap(epginfo);
}

bool MythEPGInfo::IsNull() const
{
  if (!m_epginfo)
    return true;
  return m_epginfo.get() == NULL;
}

Myth::ProgramPtr MythEPGInfo::GetPtr() const
{
  return m_epginfo;
}

uint32_t MythEPGInfo::ChannelID() const
{
  return (m_epginfo ? m_epginfo->channel.chanId : 0);
}

std::string MythEPGInfo::ChannelName() const
{
  return (m_epginfo ? m_epginfo->channel.channelName : "" );
}

std::string MythEPGInfo::Callsign() const
{
  return (m_epginfo ? m_epginfo->channel.callSign : "");
}

uint32_t MythEPGInfo::SourceID() const
{
  return (m_epginfo ? m_epginfo->channel.sourceId : 0);
}

std::string MythEPGInfo::Title() const
{
  return (m_epginfo ? m_epginfo->title : "");
}

std::string MythEPGInfo::Subtitle() const
{
  return (m_epginfo ? m_epginfo->subTitle : "");
}

std::string MythEPGInfo::Description() const
{
  return (m_epginfo ? m_epginfo->description : "");
}

time_t MythEPGInfo::StartTime() const
{
  return (m_epginfo ? m_epginfo->startTime : (time_t)(-1));
}

time_t MythEPGInfo::EndTime() const
{
  return (m_epginfo ? m_epginfo->endTime : (time_t)(-1));
}

std::string MythEPGInfo::ProgramID() const
{
  return (m_epginfo ? m_epginfo->programId : "");
}

std::string MythEPGInfo::SeriesID() const
{
  return (m_epginfo ? m_epginfo->seriesId : "");
}

std::string MythEPGInfo::Category() const
{
  return (m_epginfo ? m_epginfo->category : "");
}

std::string MythEPGInfo::CategoryType() const
{
  return (m_epginfo ? m_epginfo->catType : "");
}

std::string MythEPGInfo::ChannelNumber() const
{
  return (m_epginfo ? m_epginfo->channel.chanNum : "");
}

// Broacast ID is 32 bits integer and allows to identify a EPG item.
// MythTV backend doesn't provide one. So we make it encoding time and channel
// as below:
// 31. . . . . . . . . . . . . . . 15. . . . . . . . . . . . . . 0
// [   timecode (self-relative)   ][         channel Id          ]
// Timecode is the count of minutes since epoch modulo 0xFFFF. Now therefore it
// is usable for a period of +/- 32767 minutes (+/-22 days) around itself.

int MythEPGInfo::MakeBroadcastID(unsigned int chanid, time_t starttime)
{
  int timecode = (int)(difftime(starttime, 0) / INTERVAL_MINUTE) & 0xFFFF;
  return (int)((timecode << 16) | (chanid & 0xFFFF));
}

void MythEPGInfo::BreakBroadcastID(int broadcastid, unsigned int *chanid, time_t *attime)
{
  time_t now;
  int ntc, ptc, distance;
  struct tm epgtm;

  now = time(NULL);
  ntc = (int)(difftime(now, 0) / INTERVAL_MINUTE) & 0xFFFF;
  ptc = (broadcastid >> 16) & 0xFFFF; // removes arithmetic bits
  if (ptc > ntc)
    distance = (ptc - ntc) < 0x8000 ? ptc - ntc : ptc - ntc - 0xFFFF;
  else
    distance = (ntc - ptc) < 0x8000 ? ptc - ntc : ptc - ntc + 0xFFFF;
  localtime_r(&now, &epgtm);
  epgtm.tm_min += distance;
  // Time precision is minute, so we are looking for program started before next minute.
  epgtm.tm_sec = INTERVAL_MINUTE - 1;

  *attime = mktime(&epgtm);
  *chanid = (unsigned int)broadcastid & 0xFFFF;
}

int MythEPGInfo::MakeBroadcastID()
{
  return (m_epginfo ? MakeBroadcastID(m_epginfo->channel.chanId, m_epginfo->startTime) : 0);
}
