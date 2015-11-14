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

#include "mythlivetvplayback.h"
#include "mythdebug.h"
#include "private/mythsocket.h"
#include "private/os/threads/mutex.h"
#include "private/os/threads/timeout.h"
#include "private/builtin.h"

#include <limits>
#include <cstdio>
#include <cstdlib>

#define MIN_TUNE_DELAY        5
#define MAX_TUNE_DELAY        60
#define TICK_USEC             100000  // valid range: 10000 - 999999
#define START_TIMEOUT         2000    // millisec
#define AHEAD_TIMEOUT         10000   // millisec

using namespace Myth;

///////////////////////////////////////////////////////////////////////////////
////
//// Protocol connection to control LiveTV playback
////

LiveTVPlayback::LiveTVPlayback(EventHandler& handler)
: ProtoMonitor(handler.GetServer(), handler.GetPort()), EventSubscriber()
, m_eventHandler(handler)
, m_eventSubscriberId(0)
, m_tuneDelay(MIN_TUNE_DELAY)
, m_limitTuneAttempts(true)
, m_recorder()
, m_signal()
, m_chain()
{
  m_eventSubscriberId = m_eventHandler.CreateSubscription(this);
  m_eventHandler.SubscribeForEvent(m_eventSubscriberId, EVENT_SIGNAL);
  m_eventHandler.SubscribeForEvent(m_eventSubscriberId, EVENT_LIVETV_CHAIN);
  m_eventHandler.SubscribeForEvent(m_eventSubscriberId, EVENT_LIVETV_WATCH);
  m_eventHandler.SubscribeForEvent(m_eventSubscriberId, EVENT_DONE_RECORDING);
  m_eventHandler.SubscribeForEvent(m_eventSubscriberId, EVENT_UPDATE_FILE_SIZE);
  Open();
}

LiveTVPlayback::LiveTVPlayback(const std::string& server, unsigned port)
: ProtoMonitor(server, port), EventSubscriber()
, m_eventHandler(server, port)
, m_eventSubscriberId(0)
, m_tuneDelay(MIN_TUNE_DELAY)
, m_recorder()
, m_signal()
, m_chain()
{
  // Private handler will be stopped and closed by destructor.
  m_eventSubscriberId = m_eventHandler.CreateSubscription(this);
  m_eventHandler.SubscribeForEvent(m_eventSubscriberId, EVENT_SIGNAL);
  m_eventHandler.SubscribeForEvent(m_eventSubscriberId, EVENT_LIVETV_CHAIN);
  m_eventHandler.SubscribeForEvent(m_eventSubscriberId, EVENT_LIVETV_WATCH);
  m_eventHandler.SubscribeForEvent(m_eventSubscriberId, EVENT_DONE_RECORDING);
  m_eventHandler.SubscribeForEvent(m_eventSubscriberId, EVENT_UPDATE_FILE_SIZE);
  Open();
}

LiveTVPlayback::~LiveTVPlayback()
{
  if (m_eventSubscriberId)
    m_eventHandler.RevokeSubscription(m_eventSubscriberId);
  Close();
}

bool LiveTVPlayback::Open()
{
  // Begin critical section
  OS::CLockGuard lock(*m_mutex);
  if (ProtoMonitor::IsOpen())
    return true;
  if (ProtoMonitor::Open())
  {
    if (!m_eventHandler.IsRunning())
    {
      OS::CTimeout timeout(START_TIMEOUT);
      m_eventHandler.Start();
      do
      {
        usleep(TICK_USEC);
      }
      while (!m_eventHandler.IsConnected() && timeout.TimeLeft() > 0);
      if (!m_eventHandler.IsConnected())
        DBG(MYTH_DBG_WARN, "%s: event handler is not connected in time\n", __FUNCTION__);
      else
        DBG(MYTH_DBG_DEBUG, "%s: event handler is connected\n", __FUNCTION__);
    }
    return true;
  }
  return false;
}

void LiveTVPlayback::Close()
{
  // Begin critical section
  OS::CLockGuard lock(*m_mutex);
  m_recorder.reset();
  ProtoMonitor::Close();
}

void LiveTVPlayback::SetTuneDelay(unsigned delay)
{
  if (delay < MIN_TUNE_DELAY)
    m_tuneDelay = MIN_TUNE_DELAY;
  else if (delay > MAX_TUNE_DELAY)
    m_tuneDelay = MAX_TUNE_DELAY;
  else
    m_tuneDelay = delay;
}

void LiveTVPlayback::SetLimitTuneAttempts(bool limit)
{
  // true : Try first tunable card in prefered order
  // false: Try all tunable cards in prefered order
  m_limitTuneAttempts = limit;
}

bool LiveTVPlayback::SpawnLiveTV(const std::string& chanNum, const ChannelList& channels)
{
  // Begin critical section
  OS::CLockGuard lock(*m_mutex);
  if (!ProtoMonitor::IsOpen() || !m_eventHandler.IsConnected())
  {
    DBG(MYTH_DBG_ERROR, "%s: not connected\n", __FUNCTION__);
    return false;
  }

  StopLiveTV();
  preferredCards_t preferredCards = FindTunableCardIds(chanNum, channels);
  preferredCards_t::const_iterator card = preferredCards.begin();
  while (card != preferredCards.end())
  {
    InitChain(); // Setup chain
    const CardInputPtr& input = card->second.first;
    const ChannelPtr& channel = card->second.second;
    DBG(MYTH_DBG_DEBUG, "%s: trying recorder num (%" PRIu32 ") channum (%s)\n", __FUNCTION__, input->cardId, channel->chanNum.c_str());
    m_recorder = GetRecorderFromNum((int) input->cardId);
    // Setup the chain
    m_chain.switchOnCreate = true;
    m_chain.watch = true;
    if (m_recorder->SpawnLiveTV(m_chain.UID, channel->chanNum))
    {
      // Wait chain update until time limit
      uint32_t delayMs = m_tuneDelay * 1000;
      OS::CTimeout timeout(delayMs);
      do
      {
        lock.Unlock();  // Release the latch to allow chain update
        usleep(TICK_USEC);
        lock.Lock();
        if (!m_chain.switchOnCreate)
        {
          DBG(MYTH_DBG_DEBUG, "%s: tune delay (%" PRIu32 "ms)\n", __FUNCTION__, (delayMs - timeout.TimeLeft()));
          return true;
        }
      }
      while (timeout.TimeLeft() > 0);
      DBG(MYTH_DBG_ERROR, "%s: tune delay exceeded (%" PRIu32 "ms)\n", __FUNCTION__, delayMs);
      m_recorder->StopLiveTV();
    }
    ClearChain();
    // Check if we need to stop after first attempt at tuning
    if (m_limitTuneAttempts)
    {
      DBG(MYTH_DBG_DEBUG, "%s: limiting tune attempts to first tunable card\n", __FUNCTION__);
      break;
    }
    // Retry the next preferred card
    ++card;
  }
  return false;
}

bool LiveTVPlayback::SpawnLiveTV(const ChannelPtr& thisChannel)
{
  ChannelList list;
  list.push_back(thisChannel);
  return SpawnLiveTV(thisChannel->chanNum, list);
}

void LiveTVPlayback::StopLiveTV()
{
  // Begin critical section
  OS::CLockGuard lock(*m_mutex);
  if (m_recorder && m_recorder->IsPlaying())
  {
    m_recorder->StopLiveTV();
    // If recorder is keeping recording then release it to clear my instance status.
    // Otherwise next program would be considered as preserved.
    if (m_recorder->IsLiveRecording())
      m_recorder.reset();
  }
}

void LiveTVPlayback::InitChain()
{
  char buf[32];
  // Begin critical section
  OS::CLockGuard lock(*m_mutex);
  time_to_iso8601(time(NULL), buf);
  m_chain.UID = m_socket->GetMyHostName();
  m_chain.UID.append("-").append(buf);
  m_chain.currentSequence = 0;
  m_chain.lastSequence = 0;
  m_chain.watch = false;
  m_chain.switchOnCreate = true;
  m_chain.chained.clear();
  m_chain.currentTransfer.reset();
}

void LiveTVPlayback::ClearChain()
{
  // Begin critical section
  OS::CLockGuard lock(*m_mutex);
  m_chain.currentSequence = 0;
  m_chain.lastSequence = 0;
  m_chain.watch = false;
  m_chain.switchOnCreate = false;
  m_chain.chained.clear();
  m_chain.currentTransfer.reset();
}

bool LiveTVPlayback::IsChained(const Program& program)
{
  for (chained_t::const_iterator it = m_chain.chained.begin(); it != m_chain.chained.end(); ++it)
  {
    if (it->first && it->first->GetPathName() == program.fileName)
      return true;
  }
  return false;
}

void LiveTVPlayback::HandleChainUpdate()
{
  OS::CLockGuard lock(*m_mutex); // Lock chain
  ProtoRecorderPtr recorder(m_recorder);
  if (!recorder)
    return;
  ProgramPtr prog = recorder->GetCurrentRecording();
  /*
   * If program file doesn't exist in the recorder chain then create a new
   * transfer and add it to the chain.
   */
  if (prog && !prog->fileName.empty() && !IsChained(*prog))
  {
    DBG(MYTH_DBG_DEBUG, "%s: liveTV (%s): adding new transfer %s\n", __FUNCTION__,
            m_chain.UID.c_str(), prog->fileName.c_str());
    ProtoTransferPtr transfer(new ProtoTransfer(recorder->GetServer(), recorder->GetPort(), prog->fileName, prog->recording.storageGroup));
    // Pop previous dummy file if exists then add the new into the chain
    if (m_chain.lastSequence && m_chain.chained[m_chain.lastSequence - 1].first->GetSize() == 0)
    {
      --m_chain.lastSequence;
      m_chain.chained.pop_back();
    }
    m_chain.chained.push_back(std::make_pair(transfer, prog));
    m_chain.lastSequence = m_chain.chained.size();
    /*
     * If switchOnCreate flag and file is filled then switch immediatly.
     * Else we will switch later on the next event 'UPDATE_FILE_SIZE'
     */
    if (m_chain.switchOnCreate && transfer->GetSize() > 0 && SwitchChainLast())
      m_chain.switchOnCreate = false;
    m_chain.watch = false; // Chain update done. Restore watch flag
    DBG(MYTH_DBG_DEBUG, "%s: liveTV (%s): chain last (%u), watching (%u)\n", __FUNCTION__,
            m_chain.UID.c_str(), m_chain.lastSequence, m_chain.currentSequence);
  }
}

bool LiveTVPlayback::SwitchChain(unsigned sequence)
{
  OS::CLockGuard lock(*m_mutex);
  // Check for out of range
  if (sequence < 1 || sequence > m_chain.lastSequence)
    return false;
  // If closed then try to open
  if (!m_chain.chained[sequence - 1].first->IsOpen() && !m_chain.chained[sequence - 1].first->Open())
    return false;
  m_chain.currentTransfer = m_chain.chained[sequence - 1].first;
  m_chain.currentSequence = sequence;
  DBG(MYTH_DBG_DEBUG, "%s: switch to file (%u) %s\n", __FUNCTION__,
          (unsigned)m_chain.currentTransfer->GetFileId(), m_chain.currentTransfer->GetPathName().c_str());
  return true;
}

bool LiveTVPlayback::SwitchChainLast()
{
  if (SwitchChain(m_chain.lastSequence))
  {
    ProtoRecorderPtr recorder(m_recorder);
    ProtoTransferPtr transfer(m_chain.currentTransfer);
    if (recorder && transfer && recorder->TransferSeek(*transfer, 0, WHENCE_SET) == 0)
      return true;
  }
  return false;
}

void LiveTVPlayback::HandleBackendMessage(EventMessagePtr msg)
{
  ProtoRecorderPtr recorder(m_recorder);
  if (!recorder || !recorder->IsPlaying())
    return;
  switch (msg->event)
  {
    /*
     * Event: LIVETV_CHAIN UPDATE
     *
     * Called in response to the backend's notification of a chain update.
     * The recorder is supplied and will be queried for the current recording
     * to determine if a new file needs to be added to the chain of files
     * in the live tv instance.
     */
    case EVENT_LIVETV_CHAIN:
      if (msg->subject.size() >= 3)
      {
        if (msg->subject[1] == "UPDATE" && msg->subject[2] == m_chain.UID)
          HandleChainUpdate();
      }
      break;
    /*
     * Event: LIVETV_WATCH
     *
     * Called in response to the backend's notification of a livetv watch.
     * The recorder is supplied and will be updated for the watch signal.
     * This event is used to manage program breaks while watching live tv.
     * When the guide data marks the end of one show and the beginning of
     * the next, which will be recorded to a new file, this instructs the
     * frontend to terminate the existing playback, and change channel to
     * the new file. Before updating livetv chain and switching to new file
     * we must to wait for event DONE_RECORDING that informs the current
     * show is completed. Then we will call livetv chain update to get
     * current program info. Watch signal will be down during this period.
     */
    case EVENT_LIVETV_WATCH:
      if (msg->subject.size() >= 3)
      {
        int32_t rnum;
        int8_t flag;
        if (string_to_int32(msg->subject[1].c_str(), &rnum) == 0 && string_to_int8(msg->subject[2].c_str(), &flag) == 0)
        {
          if (recorder->GetNum() == (int)rnum)
          {
            OS::CLockGuard lock(*m_mutex); // Lock chain
            m_chain.watch = true;
          }
        }
      }
      break;
    /*
     * Event: DONE_RECORDING
     *
     * Indicates that an active recording has completed on the specified
     * recorder. used to manage program breaks while watching live tv.
     * When receive event for recorder, we force an update of livetv chain
     * to get current program info when chain is not yet updated.
     * Watch signal is used when up, to mark the break period and
     * queuing the frontend for reading file buffer.
     */
    case EVENT_DONE_RECORDING:
      if (msg->subject.size() >= 2)
      {
        int32_t rnum;
        if (string_to_int32(msg->subject[1].c_str(), &rnum) == 0 && recorder->GetNum() == (int)rnum)
        {
          // Recorder is not subscriber. So callback event to it
          recorder->DoneRecordingCallback();
          // Manage program break
          if (m_chain.watch)
          {
            /*
             * Last recording is now completed but watch signal is ON.
             * Then force live tv chain update for the new current
             * program. We will retry for 2s before returning.
             */
            OS::CTimeout timeout(2000);
            do
            {
              usleep(500000); // wait for 500 ms
              HandleChainUpdate();
            }
            while (m_chain.watch && timeout.TimeLeft() > 0);
          }
        }
      }
      break;
    case EVENT_UPDATE_FILE_SIZE:
      if (msg->subject.size() >= 3)
      {
        OS::CLockGuard lock(*m_mutex); // Lock chain
        if (m_chain.lastSequence > 0)
        {
          int64_t newsize;
          // Message contains chanid + starttime as recorded key
          if (msg->subject.size() >= 4)
          {
            uint32_t chanid;
            time_t startts;
            if (string_to_uint32(msg->subject[1].c_str(), &chanid)
                    || string_to_time(msg->subject[2].c_str(), &startts)
                    || m_chain.chained[m_chain.lastSequence -1].second->channel.chanId != chanid
                    || m_chain.chained[m_chain.lastSequence -1].second->recording.startTs != startts
                    || string_to_int64(msg->subject[3].c_str(), &newsize)
                    || m_chain.chained[m_chain.lastSequence - 1].first->GetSize() >= newsize)
              break;
          }
          // Message contains recordedid as key
          else
          {
            uint32_t recordedid;
            if (string_to_uint32(msg->subject[1].c_str(), &recordedid)
                    || m_chain.chained[m_chain.lastSequence -1].second->recording.recordedId != recordedid
                    || string_to_int64(msg->subject[2].c_str(), &newsize)
                    || m_chain.chained[m_chain.lastSequence - 1].first->GetSize() >= newsize)
              break;
          }
          // Update transfer file size
          m_chain.chained[m_chain.lastSequence - 1].first->SetSize(newsize);
          // Is wait the filling before switching ?
          if (m_chain.switchOnCreate && SwitchChainLast())
            m_chain.switchOnCreate = false;
          DBG(MYTH_DBG_DEBUG, "%s: liveTV (%s): chain last (%u) filesize %" PRIi64 "\n", __FUNCTION__,
                  m_chain.UID.c_str(), m_chain.lastSequence, newsize);
        }
      }
      break;
    case EVENT_SIGNAL:
      if (msg->subject.size() >= 2)
      {
        int32_t rnum;
        if (string_to_int32(msg->subject[1].c_str(), &rnum) == 0 && recorder->GetNum() == (int)rnum)
          m_signal = msg->signal;
      }
      break;
    //case EVENT_HANDLER_STATUS:
    //  if (msg->subject[0] == EVENTHANDLER_DISCONNECTED)
    //    closeTransfer();
    //  break;
    default:
      break;
  }
}

int64_t LiveTVPlayback::GetSize() const
{
  int64_t size = 0;
  OS::CLockGuard lock(*m_mutex); // Lock chain
  for (chained_t::const_iterator it = m_chain.chained.begin(); it != m_chain.chained.end(); ++it)
    size += it->first->GetSize();
  return size;
}

int LiveTVPlayback::Read(void* buffer, unsigned n)
{
  int r = 0;
  bool retry;
  int64_t s, fp;

  // Begin critical section
  // First of all i hold my shared resources using copies
  ProtoRecorderPtr recorder(m_recorder);
  if (!m_chain.currentTransfer || !recorder)
    return -1;

  fp = m_chain.currentTransfer->GetPosition();

  do
  {
    retry = false;
    s = m_chain.currentTransfer->GetRemaining();  // Acceptable block size
    if (s == 0)
    {
      OS::CTimeout timeout(AHEAD_TIMEOUT);
      for (;;)
      {
        // Reading ahead
        if (m_chain.currentSequence == m_chain.lastSequence)
        {
          int64_t rp = recorder->GetFilePosition();
          if (rp > fp)
          {
            m_chain.currentTransfer->SetSize(rp);
            retry = true;
            break;
          }
          if (!timeout.TimeLeft())
          {
            DBG(MYTH_DBG_WARN, "%s: read position is ahead (%" PRIi64 ")\n", __FUNCTION__, fp);
            return 0;
          }
          usleep(500000);
        }
        // Switch next file transfer is required to continue
        else
        {
          if (!SwitchChain(m_chain.currentSequence + 1))
            return -1;
          if (m_chain.currentTransfer->GetPosition() != 0)
            recorder->TransferSeek(*(m_chain.currentTransfer), 0, WHENCE_SET);
          DBG(MYTH_DBG_DEBUG, "%s: liveTV (%s): chain last (%u), watching (%u)\n", __FUNCTION__,
                m_chain.UID.c_str(), m_chain.lastSequence, m_chain.currentSequence);
          retry = true;
          break;
        }
      }
    }
    else if (s < 0)
      return -1;
  }
  while (retry);

  if (s < (int64_t)n)
    n = (unsigned)s ;

  r = recorder->TransferRequestBlock(*(m_chain.currentTransfer), buffer, n);
  return r;
}

int64_t LiveTVPlayback::Seek(int64_t offset, WHENCE_t whence)
{
  OS::CLockGuard lock(*m_mutex); // Lock chain
  if (!m_recorder || !m_chain.currentSequence)
    return -1;

  unsigned ci = m_chain.currentSequence - 1; // current sequence index
  int64_t size = GetSize(); // total stream size
  int64_t position = GetPosition(); // absolute position in stream
  int64_t p = 0;
  switch (whence)
  {
  case WHENCE_SET:
    p = offset;
    break;
  case WHENCE_END:
    p = size + offset;
    break;
  case WHENCE_CUR:
    p = position + offset;
    break;
  default:
    return -1;
  }
  if (p > size || p < 0)
  {
    DBG(MYTH_DBG_WARN, "%s: invalid seek (%" PRId64 ")\n", __FUNCTION__, p);
    return -1;
  }
  if (p > position)
  {
    for (;;)
    {
      if (position + m_chain.chained[ci].first->GetRemaining() >= p)
      {
        // Try seek file to desired position. On success switch chain
        if (m_recorder->TransferSeek(*(m_chain.chained[ci].first), p - position, WHENCE_CUR) < 0 ||
                !SwitchChain(++ci))
          return -1;
        return p;
      }
      position += m_chain.chained[ci].first->GetRemaining();
      ++ci; // switch next
      if (ci < m_chain.lastSequence)
        position += m_chain.chained[ci].first->GetPosition();
      else
        return -1;
    }
  }
  if (p < position)
  {
    for (;;)
    {
      if (position - m_chain.chained[ci].first->GetPosition() <= p)
      {
        // Try seek file to desired position. On success switch chain
        if (m_recorder->TransferSeek(*(m_chain.chained[ci].first), p - position, WHENCE_CUR) < 0 ||
                !SwitchChain(++ci))
          return -1;
        return p;
      }
      position -= m_chain.chained[ci].first->GetPosition();
      if (ci > 0)
      {
        --ci; // switch previous
        position -= m_chain.chained[ci].first->GetRemaining();
      }
      else
        return -1;
    }
  }
  // p == position
  return p;
}

int64_t LiveTVPlayback::GetPosition() const
{
  int64_t pos = 0;
  OS::CLockGuard lock(*m_mutex); // Lock chain
  if (m_chain.currentSequence)
  {
    unsigned s = m_chain.currentSequence - 1;
    for (unsigned i = 0; i < s; ++i)
      pos += m_chain.chained[i].first->GetSize();
    pos += m_chain.currentTransfer->GetPosition();
  }
  return pos;
}

bool LiveTVPlayback::IsPlaying() const
{
  ProtoRecorderPtr recorder(m_recorder);
  return (recorder ? recorder->IsPlaying() : false);
}

bool LiveTVPlayback::IsLiveRecording() const
{
  ProtoRecorderPtr recorder(m_recorder);
  return (recorder ? recorder->IsLiveRecording() : false);
}

bool LiveTVPlayback::KeepLiveRecording(bool keep)
{
  ProtoRecorderPtr recorder(m_recorder);
  // Begin critical section
  OS::CLockGuard lock(*m_mutex);
  if (recorder && recorder->IsPlaying())
  {
    ProgramPtr prog = recorder->GetCurrentRecording();
    if (prog)
    {
      if (keep)
      {
        if (UndeleteRecording(*prog) && recorder->SetLiveRecording(keep))
        {
          QueryGenpixmap(*prog);
          return true;
        }
      }
      else
      {
        if (recorder->SetLiveRecording(keep) && recorder->FinishRecording())
          return true;
      }
    }
  }
  return false;
}

ProgramPtr LiveTVPlayback::GetPlayedProgram() const
{
  OS::CLockGuard lock(*m_mutex); // Lock chain
  if (m_chain.currentSequence > 0)
    return m_chain.chained[m_chain.currentSequence - 1].second;
  return ProgramPtr();
}

time_t LiveTVPlayback::GetLiveTimeStart() const
{
  OS::CLockGuard lock(*m_mutex); // Lock chain
  if (m_chain.lastSequence)
    return m_chain.chained[0].second->recording.startTs;
  return (time_t)(-1);
}

unsigned LiveTVPlayback::GetChainedCount() const
{
  OS::CLockGuard lock(*m_mutex); // Lock chain
  return m_chain.lastSequence;
}

ProgramPtr LiveTVPlayback::GetChainedProgram(unsigned sequence) const
{
  OS::CLockGuard lock(*m_mutex); // Lock chain
  if (sequence > 0 && sequence <= m_chain.lastSequence)
    return m_chain.chained[sequence - 1].second;
  return ProgramPtr();
}

uint32_t LiveTVPlayback::GetCardId() const
{
  ProtoRecorderPtr recorder(m_recorder);
  return (recorder ? recorder->GetNum() : 0);
}

SignalStatusPtr LiveTVPlayback::GetSignal() const
{
  return (m_recorder ? m_signal : SignalStatusPtr());
}

LiveTVPlayback::preferredCards_t LiveTVPlayback::FindTunableCardIds75(const std::string& chanNum, const ChannelList& channels)
{
  // Make the set of channels matching the desired channel number
  ChannelList chanset;
  for (ChannelList::const_iterator it = channels.begin(); it != channels.end(); ++it)
  {
    if ((*it)->chanNum == chanNum)
      chanset.push_back(*it);
  }
  // Retrieve unlocked encoders and fill the list of preferred cards.
  // It is ordered by its key liveTVOrder and contains matching between channels
  // and card inputs using their respective sourceId and mplexId
  std::vector<int> ids = GetFreeCardIdList();
  preferredCards_t preferredCards;
  for (std::vector<int>::const_iterator itc = ids.begin(); itc != ids.end(); ++itc)
  {
    CardInputListPtr inputs = GetFreeInputs(*itc);
    for (CardInputList::const_iterator iti = inputs->begin(); iti != inputs->end(); ++iti)
    {
      for (ChannelList::const_iterator itchan = chanset.begin(); itchan != chanset.end(); ++itchan)
      {
        if ((*itchan)->sourceId == (*iti)->sourceId && ( (*iti)->mplexId == 0 || (*iti)->mplexId == (*itchan)->mplexId ))
        {
          preferredCards.insert(std::make_pair((*iti)->liveTVOrder, std::make_pair(*iti, *itchan)));
          DBG(MYTH_DBG_DEBUG, "%s: [%u] channel=%s(%" PRIu32 ") card=%" PRIu32 " input=%s(%" PRIu32 ") mplex=%" PRIu32 " source=%" PRIu32 "\n",
                  __FUNCTION__, (*iti)->liveTVOrder, (*itchan)->callSign.c_str(), (*itchan)->chanId,
                  (*iti)->cardId, (*iti)->inputName.c_str(), (*iti)->inputId, (*iti)->mplexId, (*iti)->sourceId);
          break;
        }
      }
    }
  }
  return preferredCards;
}

LiveTVPlayback::preferredCards_t LiveTVPlayback::FindTunableCardIds87(const std::string& chanNum, const ChannelList& channels)
{
  // Make the set of channels matching the desired channel number
  ChannelList chanset;
  for (ChannelList::const_iterator it = channels.begin(); it != channels.end(); ++it)
  {
    if ((*it)->chanNum == chanNum)
      chanset.push_back(*it);
  }
  // Retrieve unlocked encoders and fill the list of preferred cards.
  // It is ordered by its key liveTVOrder and contains matching between channels
  // and card inputs using their respective sourceId and mplexId
  preferredCards_t preferredCards;
  CardInputListPtr inputs = GetFreeInputs(0);
  for (CardInputList::const_iterator iti = inputs->begin(); iti != inputs->end(); ++iti)
  {
    for (ChannelList::const_iterator itchan = chanset.begin(); itchan != chanset.end(); ++itchan)
    {
      if ((*itchan)->sourceId == (*iti)->sourceId && ( (*iti)->mplexId == 0 || (*iti)->mplexId == (*itchan)->mplexId ))
      {
        preferredCards.insert(std::make_pair((*iti)->liveTVOrder, std::make_pair(*iti, *itchan)));
        DBG(MYTH_DBG_DEBUG, "%s: [%u] channel=%s(%" PRIu32 ") card=%" PRIu32 " input=%s(%" PRIu32 ") mplex=%" PRIu32 " source=%" PRIu32 "\n",
                __FUNCTION__, (*iti)->liveTVOrder, (*itchan)->callSign.c_str(), (*itchan)->chanId,
                (*iti)->cardId, (*iti)->inputName.c_str(), (*iti)->inputId, (*iti)->mplexId, (*iti)->sourceId);
        break;
      }
    }
  }
  return preferredCards;
}
