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

#ifndef MYTHLIVETVPLAYBACK_H
#define	MYTHLIVETVPLAYBACK_H

#include "proto/mythprotorecorder.h"
#include "proto/mythprototransfer.h"
#include "proto/mythprotomonitor.h"
#include "mythstream.h"
#include "mytheventhandler.h"
#include "mythtypes.h"

#include <vector>

namespace Myth
{

  class LiveTVPlayback : private ProtoMonitor, public Stream, private EventSubscriber
  {
  public:
    LiveTVPlayback(EventHandler& handler);
    LiveTVPlayback(const std::string& server, unsigned port);
    ~LiveTVPlayback();

    bool Open();
    void Close();
    bool IsOpen() { return ProtoMonitor::IsOpen(); }
    void SetTuneDelay(unsigned delay);
    void SetLimitTuneAttempts(bool limit);
    bool SpawnLiveTV(const std::string& chanNum, const ChannelList& channels);
    bool SpawnLiveTV(const ChannelPtr& thisChannel);
    void StopLiveTV();

    // Implement Stream
    int64_t GetSize() const;
    int Read(void *buffer, unsigned n);
    int64_t Seek(int64_t offset, WHENCE_t whence);
    int64_t GetPosition() const;

    bool IsPlaying() const;
    bool IsLiveRecording() const;
    bool KeepLiveRecording(bool keep);
    ProgramPtr GetPlayedProgram() const;
    time_t GetLiveTimeStart() const;
    unsigned GetChainedCount() const;
    ProgramPtr GetChainedProgram(unsigned sequence) const;
    uint32_t GetCardId() const;
    SignalStatusPtr GetSignal() const;

    // Implement EventSubscriber
    void HandleBackendMessage(EventMessagePtr msg);

  private:
    EventHandler m_eventHandler;
    unsigned m_eventSubscriberId;

    unsigned m_tuneDelay;
    bool m_limitTuneAttempts;
    ProtoRecorderPtr m_recorder;
    SignalStatusPtr m_signal;

    typedef std::vector<std::pair<ProtoTransferPtr, ProgramPtr> > chained_t;
    struct {
      std::string UID;
      chained_t chained;
      ProtoTransferPtr currentTransfer;
      volatile unsigned currentSequence;
      volatile unsigned lastSequence;
      volatile bool watch;
      volatile bool switchOnCreate;
    } m_chain;

    void InitChain();
    void ClearChain();
    bool IsChained(const Program& program);
    void HandleChainUpdate();
    bool SwitchChain(unsigned sequence);
    bool SwitchChainLast();

    typedef std::multimap<unsigned, std::pair<CardInputPtr, ChannelPtr> > preferredCards_t;
    preferredCards_t FindTunableCardIds(const std::string& chanNum, const ChannelList& channels)
    {
      if (m_protoVersion >= 87) return FindTunableCardIds87(chanNum, channels);
      return FindTunableCardIds75(chanNum, channels);
    }
    preferredCards_t FindTunableCardIds75(const std::string& chanNum, const ChannelList& channels);
    preferredCards_t FindTunableCardIds87(const std::string& chanNum, const ChannelList& channels);
  };

}

#endif	/* MYTHLIVETVPLAYBACK_H */

