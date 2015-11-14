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

#include "MythChannel.h"

#include <cctype>
#include <cstring>
#include <cstdlib>

#define CHANNUM_STR_SIZE  10

MythChannel::MythChannel()
: m_channel()
, m_numMajor(0)
, m_numMinor(0)
{
}

MythChannel::MythChannel(Myth::ChannelPtr channel)
  : m_channel()
{
  m_channel.swap(channel);
  if (m_channel)
  {
    BreakNumber(m_channel->chanNum.c_str(), &m_numMajor, &m_numMinor);
  }
  else
  {
    m_numMajor = 0;
    m_numMinor = 0;
  }
}

void MythChannel::BreakNumber(const char *numstr, unsigned *major, unsigned *minor)
{
  // ATSC channel number use "_" or "." for major and minor separator
  char str[CHANNUM_STR_SIZE + 1];
  char *p1 = str;
  char *p2 = str;
  strncpy(str, numstr, CHANNUM_STR_SIZE);
  str[CHANNUM_STR_SIZE] = '\0';
  while(isspace(*p1))
    ++p1;
  p2 = p1;
  while (isdigit(*p2))
    ++p2;
  *p2++ = '\0';
  *major = (unsigned)atoi(p1);
  p1 = p2;
  while (isdigit(*p2))
    ++p2;
  *p2 = '\0';
  *minor = (unsigned)atoi(p1);
}

bool MythChannel::IsNull() const
{
  if (!m_channel)
    return true;
  return m_channel.get() == NULL;
}

Myth::ChannelPtr MythChannel::GetPtr() const
{
  return m_channel;
}

uint32_t MythChannel::ID() const
{
  return (m_channel ? m_channel->chanId : 0);
}

std::string MythChannel::Name() const
{
  return (m_channel ? m_channel->channelName : "");
}

std::string MythChannel::Number() const
{
  return (m_channel ? m_channel->chanNum : "");
}

std::string MythChannel::Callsign() const
{
  return (m_channel ? m_channel->callSign : "");
}

std::string MythChannel::Icon() const
{
  return (m_channel ? m_channel->iconURL : "");
}

bool MythChannel::Visible() const
{
  return (m_channel ? m_channel->visible : false);
}

bool MythChannel::IsRadio() const
{
  return (false);
}

uint32_t MythChannel::SourceID() const
{
  return (m_channel ? m_channel->sourceId : 0);
}

uint32_t MythChannel::MultiplexID() const
{
  return (m_channel ? m_channel->mplexId : 0);
}
