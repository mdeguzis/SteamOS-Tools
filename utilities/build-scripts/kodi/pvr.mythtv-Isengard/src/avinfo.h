#pragma once
/*
 *      Copyright (C) 2005-2013 Team XBMC
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
 *  along with XBMC; see the file COPYING.  If not, write to
 *  the Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston,
 *  MA 02110-1301 USA
 *  http://www.gnu.org/copyleft/gpl.html
 *
 */

#include "demuxer/tsDemuxer.h"
#include "client.h"

#include <mythstream.h>

#include <set>
#include <vector>

#define AV_BUFFER_SIZE          131072

class AVInfo : public TSDemux::TSDemuxer
{
public:
  AVInfo(Myth::Stream *file);
  ~AVInfo();

  const unsigned char* ReadAV(uint64_t pos, size_t n);

  typedef struct
  {
    uint16_t pid;
    TSDemux::STREAM_TYPE stream_type;
    TSDemux::STREAM_INFO stream_info;
  } STREAM_AVINFO;

  bool GetMainStream(STREAM_AVINFO *info) const;
  std::vector<STREAM_AVINFO> GetStreams() const;

private:
  Myth::Stream *m_file;
  uint16_t m_channel;

  void Process();

  bool get_stream_data(TSDemux::STREAM_PKT* pkt);
  void populate_pvr_streams();
  bool update_pvr_stream(uint16_t pid);

  // AV raw buffer
  size_t m_av_buf_size;         ///< size of av buffer
  uint64_t m_av_pos;            ///< absolute position in av
  unsigned char* m_av_buf;      ///< buffer
  unsigned char* m_av_rbs;      ///< raw data start in buffer
  unsigned char* m_av_rbe;      ///< raw data end in buffer

  // Playback context
  TSDemux::AVContext* m_AVContext;
  uint16_t m_mainStreamPID;     ///< PID of main stream
  uint64_t m_DTS;               ///< absolute decode time of main stream
  uint64_t m_PTS;               ///< absolute presentation time of main stream

  std::set<uint16_t> m_nosetup;
  int m_AVStatus;
};
