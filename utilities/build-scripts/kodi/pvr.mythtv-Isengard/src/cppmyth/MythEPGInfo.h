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

class MythEPGInfo
{
public:
  MythEPGInfo();
  MythEPGInfo(Myth::ProgramPtr epginfo);

  bool IsNull() const;
  Myth::ProgramPtr GetPtr() const;

  uint32_t ChannelID() const;
  std::string ChannelName() const;
  std::string Callsign() const;
  uint32_t SourceID() const;
  std::string Title() const;
  std::string Subtitle() const;
  std::string Description() const;
  time_t StartTime() const;
  time_t EndTime() const;
  std::string ProgramID() const;
  std::string SeriesID() const;
  std::string Category() const;
  std::string CategoryType() const;
  std::string ChannelNumber() const;

  /**
   *
   * \brief Handle broadcast UID for MythTV program
   */
  static int MakeBroadcastID(unsigned int chanid, time_t starttime);
  static void BreakBroadcastID(int broadcastid, unsigned int *chanid, time_t *starttime);
  int MakeBroadcastID();

private:
  Myth::ProgramPtr m_epginfo;
};
