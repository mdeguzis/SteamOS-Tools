/*
 *      Copyright (C) 2005-2012 Team XBMC
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

#include "bitstream.h"

using namespace TSDemux;

CBitstream::CBitstream(uint8_t *data, int bits)
{
  m_data   = data;
  m_offset = 0;
  m_len    = bits;
  m_error  = false;
}

void CBitstream::setBitstream(uint8_t *data, int bits)
{
  m_data   = data;
  m_offset = 0;
  m_len    = bits;
  m_error  = false;
}

void CBitstream::skipBits(int num)
{
  m_offset += num;
}

unsigned int CBitstream::readBits(int num)
{
  int r = 0;

  while(num > 0)
  {
    if(m_offset >= m_len)
    {
      m_error = true;
      return 0;
    }

    num--;

    if(m_data[m_offset / 8] & (1 << (7 - (m_offset & 7))))
      r |= 1 << num;

    m_offset++;
  }
  return r;
}

unsigned int CBitstream::showBits(int num)
{
  int r = 0;
  int offs = m_offset;

  while(num > 0)
  {
    if(offs >= m_len)
    {
      m_error = true;
      return 0;
    }

    num--;

    if(m_data[offs / 8] & (1 << (7 - (offs & 7))))
      r |= 1 << num;

    offs++;
  }
  return r;
}

unsigned int CBitstream::readGolombUE(int maxbits)
{
  int lzb = -1;
  int bits = 0;

  for(int b = 0; !b; lzb++, bits++)
  {
    if (bits > maxbits)
      return 0;
    b = readBits1();
  }

  return (1 << lzb) - 1 + readBits(lzb);
}

signed int CBitstream::readGolombSE()
{
  int v, pos;
  v = readGolombUE();
  if(v == 0)
    return 0;

  pos = (v & 1);
  v = (v + 1) >> 1;
  return pos ? v : -v;
}


unsigned int CBitstream::remainingBits()
{
  return m_len - m_offset;
}


void CBitstream::putBits(int val, int num)
{
  while(num > 0) {
    if(m_offset >= m_len)
    {
      m_error = true;
      return;
    }

    num--;

    if(val & (1 << num))
      m_data[m_offset / 8] |= 1 << (7 - (m_offset & 7));
    else
      m_data[m_offset / 8] &= ~(1 << (7 - (m_offset & 7)));

    m_offset++;
  }
}
