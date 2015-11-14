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

class MythChannel
{
public:
  MythChannel();
  MythChannel(Myth::ChannelPtr channel);

  bool IsNull() const;
  Myth::ChannelPtr GetPtr() const;

  uint32_t ID() const;
  std::string Name() const;
  std::string Number() const;
  std::string Callsign() const;
  std::string Icon() const;
  bool Visible() const;
  bool IsRadio() const;
  uint32_t SourceID() const;
  uint32_t MultiplexID() const;
  unsigned NumberMajor() const { return m_numMajor; }
  unsigned NumberMinor() const { return m_numMinor; }

private:
  Myth::ChannelPtr m_channel;
  unsigned m_numMajor;
  unsigned m_numMinor;

  static void BreakNumber(const char *numstr, unsigned *major, unsigned *minor);
};
