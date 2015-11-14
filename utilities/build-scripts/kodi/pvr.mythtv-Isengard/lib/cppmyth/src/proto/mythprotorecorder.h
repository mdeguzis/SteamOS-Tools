/*
 *      Copyright (C) 2014 Jean-Luc Barriere
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
 *  along with this program; see the file COPYING.  If not, write to
 *  the Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston,
 *  MA 02110-1301 USA
 *  http://www.gnu.org/copyleft/gpl.html
 *
 */

#ifndef MYTHPROTORECORDER_H
#define	MYTHPROTORECORDER_H

#include "mythprotoplayback.h"

namespace Myth
{

  class ProtoRecorder;
  typedef MYTH_SHARED_PTR<ProtoRecorder> ProtoRecorderPtr;

  class ProtoRecorder : public ProtoPlayback
  {
  public:
    ProtoRecorder(int num, const std::string& server, unsigned port);
    virtual ~ProtoRecorder();

    int GetNum() const;
    bool IsPlaying() const;
    bool IsTunable(const Channel& channel);
    void DoneRecordingCallback();

    bool SpawnLiveTV(const std::string& chainid, const std::string& channum)
    {
      return SpawnLiveTV75(chainid, channum);
    }
    bool StopLiveTV()
    {
      return StopLiveTV75();
    }
    bool CheckChannel(const std::string& channum)
    {
      return CheckChannel75(channum);
    }
    ProgramPtr GetCurrentRecording()
    {
      return GetCurrentRecording75();
    }
    int64_t GetFilePosition()
    {
      return GetFilePosition75();
    }
    CardInputListPtr GetFreeInputs()
    {
      if (m_protoVersion >= 87) return GetFreeInputs87();
      if (m_protoVersion >= 81) return GetFreeInputs81();
      if (m_protoVersion >= 79) return GetFreeInputs79();
      return GetFreeInputs75();
    }
    bool IsLiveRecording();
    bool SetLiveRecording(bool keep)
    {
      bool ret = SetLiveRecording75(keep);
      if (keep && ret)
          m_liveRecording = keep; // Hold status for this showing
      return ret;
    }
    bool FinishRecording()
    {
      return FinishRecording75();
    }

  private:
    int m_num;
    volatile bool m_playing;
    volatile bool m_liveRecording;

    bool SpawnLiveTV75(const std::string& chainid, const std::string& channum);
    bool StopLiveTV75();
    bool CheckChannel75(const std::string& channum);
    ProgramPtr GetCurrentRecording75();
    int64_t GetFilePosition75();
    CardInputListPtr GetFreeInputs75();
    CardInputListPtr GetFreeInputs79();
    CardInputListPtr GetFreeInputs81();
    CardInputListPtr GetFreeInputs87();
    bool SetLiveRecording75(bool keep);
    bool FinishRecording75();
  };

}

#endif	/* MYTHPROTORECORDER_H */
