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
 *  along with XBMC; see the file COPYING.  If not, write to
 *  the Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston,
 *  MA 02110-1301 USA
 *  http://www.gnu.org/copyleft/gpl.html
 *
 */

#include "cppmyth.h"
#include "fileOps.h"
#include "categories.h"
#include "demux.h"

#include <kodi/xbmc_pvr_types.h>
#include <platform/threads/mutex.h>
#include <mythsharedptr.h>
#include <mythcontrol.h>
#include <mytheventhandler.h>
#include <mythlivetvplayback.h>
#include <mythrecordingplayback.h>
#include <mythdebug.h>

#include <string>
#include <vector>
#include <map>

class PVRClientMythTV : public Myth::EventSubscriber, FileConsumer
{
public:
  PVRClientMythTV();
  virtual ~PVRClientMythTV();

  // Server
  typedef enum
  {
    CONN_ERROR_NO_ERROR,
    CONN_ERROR_SERVER_UNREACHABLE,
    CONN_ERROR_UNKNOWN_VERSION,
    CONN_ERROR_API_UNAVAILABLE,
  } CONN_ERROR;

  void SetDebug();
  bool Connect();
  CONN_ERROR GetConnectionError() const;
  unsigned GetBackendAPIVersion();
  const char *GetBackendName();
  const char *GetBackendVersion();
  const char *GetConnectionString();
  PVR_ERROR GetDriveSpace(long long *iTotal, long long *iUsed);
  void OnSleep();
  void OnWake();
  void OnDeactivatedGUI();
  void OnActivatedGUI();

  // Implements EventSubscriber
  void HandleBackendMessage(Myth::EventMessagePtr msg);
  void HandleChannelChange();
  void HandleScheduleChange();
  void HandleAskRecording(const Myth::EventMessage& msg);
  void HandleRecordingListChange(const Myth::EventMessage& msg);
  void RunHouseKeeping();

  // Implement FileConsumer
  void HandleCleanedCache();

  // EPG
  PVR_ERROR GetEPGForChannel(ADDON_HANDLE handle, const PVR_CHANNEL &channel, time_t iStart, time_t iEnd);

  // Channels
  int GetNumChannels();
  PVR_ERROR GetChannels(ADDON_HANDLE handle, bool bRadio);

  // Channel groups
  int GetChannelGroupsAmount();
  PVR_ERROR GetChannelGroups(ADDON_HANDLE handle, bool bRadio);
  PVR_ERROR GetChannelGroupMembers(ADDON_HANDLE handle, const PVR_CHANNEL_GROUP &group);

  // Recordings
  int GetRecordingsAmount();
  PVR_ERROR GetRecordings(ADDON_HANDLE handle);
  int GetDeletedRecordingsAmount();
  PVR_ERROR GetDeletedRecordings(ADDON_HANDLE handle);
  PVR_ERROR DeleteRecording(const PVR_RECORDING &recording);
  PVR_ERROR DeleteAndForgetRecording(const PVR_RECORDING &recording);
  PVR_ERROR SetRecordingPlayCount(const PVR_RECORDING &recording, int count);
  //PVR_ERROR SetRecordingLastPlayedPosition(const PVR_RECORDING &recording, int lastplayedposition);
  //int GetRecordingLastPlayedPosition(const PVR_RECORDING &recording);
  PVR_ERROR GetRecordingEdl(const PVR_RECORDING &recording, PVR_EDL_ENTRY entries[], int *size);
  PVR_ERROR UndeleteRecording(const PVR_RECORDING& recording);
  PVR_ERROR PurgeDeletedRecordings();

  // Timers
  int GetTimersAmount();
  PVR_ERROR GetTimers(ADDON_HANDLE handle);
  PVR_ERROR AddTimer(const PVR_TIMER &timer);
  PVR_ERROR DeleteTimer(const PVR_TIMER &timer, bool bForceDelete);
  PVR_ERROR UpdateTimer(const PVR_TIMER &timer);

  // LiveTV
  bool OpenLiveStream(const PVR_CHANNEL &channel);
  void CloseLiveStream();
  int ReadLiveStream(unsigned char *pBuffer, unsigned int iBufferSize);
  int GetCurrentClientChannel();
  bool SwitchChannel(const PVR_CHANNEL &channel);
  long long SeekLiveStream(long long iPosition, int iWhence);
  long long LengthLiveStream();
  PVR_ERROR SignalStatus(PVR_SIGNAL_STATUS &signalStatus);

  PVR_ERROR GetStreamProperties(PVR_STREAM_PROPERTIES* pProperties);
  void DemuxAbort(void);
  void DemuxFlush(void);
  DemuxPacket* DemuxRead(void);
  bool SeekTime(int time, bool backwards, double *startpts);

  time_t GetPlayingTime();
  time_t GetBufferTimeStart();
  time_t GetBufferTimeEnd();

  // Recording playback
  bool OpenRecordedStream(const PVR_RECORDING &recinfo);
  void CloseRecordedStream();
  int ReadRecordedStream(unsigned char *pBuffer, unsigned int iBufferSize);
  long long SeekRecordedStream(long long iPosition, int iWhence);
  long long LengthRecordedStream();

  // Menu hook
  PVR_ERROR CallMenuHook(const PVR_MENUHOOK &menuhook, const PVR_MENUHOOK_DATA &item);

  // Backend settings
  bool GetLiveTVPriority();
  void SetLiveTVPriority(bool enabled);
  void BlockBackendShutdown();
  void AllowBackendShutdown();

private:
  CONN_ERROR m_connectionError;
  Myth::EventHandler *m_eventHandler;
  Myth::Control *m_control;
  Myth::LiveTVPlayback *m_liveStream;
  Myth::RecordingPlayback *m_recordingStream;
  bool m_hang;
  bool m_powerSaving;

  // Backend
  FileOps *m_fileOps;
  MythScheduleManager *m_scheduleManager;
  PLATFORM::CMutex m_lock;

  // Categories
  Categories m_categories;

  // Channels
  typedef std::map<unsigned int, MythChannel> ChannelIdMap;
  ChannelIdMap m_channelsById;
  struct PVRChannelItem
  {
    unsigned int iUniqueId;
    bool bIsRadio;
    bool operator <(const PVRChannelItem& other) const { return this->iUniqueId < other.iUniqueId; }
  };
  typedef std::vector<PVRChannelItem> PVRChannelList;
  typedef std::map<std::string, PVRChannelList> PVRChannelGroupMap;
  PVRChannelList m_PVRChannels;
  PVRChannelGroupMap m_PVRChannelGroups;
  typedef std::map<unsigned int, unsigned int> PVRChannelMap;
  PVRChannelMap m_PVRChannelUidById;
  mutable PLATFORM::CMutex m_channelsLock;
  int FillChannelsAndChannelGroups();
  MythChannel FindChannel(uint32_t channelId) const;
  int FindPVRChannelUid(uint32_t channelId) const;

  // Demuxer TS
  Demux *m_demux;

  // Recordings
  ProgramInfoMap m_recordings;
  mutable PLATFORM::CMutex m_recordingsLock;
  unsigned m_recordingChangePinCount;
  bool m_recordingsAmountChange;
  int m_recordingsAmount;
  bool m_deletedRecAmountChange;
  int m_deletedRecAmount;
  void ForceUpdateRecording(ProgramInfoMap::iterator it);
  int FillRecordings();
  MythChannel FindRecordingChannel(const MythProgramInfo& programInfo) const;
  bool IsMyLiveRecording(const MythProgramInfo& programInfo);

  // Timers
  MythRecordingRule PVRtoMythRecordingRule(const PVR_TIMER &timer);
  std::map<unsigned int, MYTH_SHARED_PTR<PVR_TIMER> > m_PVRtimerMemorandum;

  /**
   * \brief Returns full title of MythTV program
   *
   * Make formatted title based on original title and subtitle of program.
   * \see class MythProgramInfo , class MythEPGInfo
   */
  static std::string MakeProgramTitle(const std::string& title, const std::string& subtitle);

  /**
   *
   * \brief Parse and fill AV stream infos for a recorded program
   */
  static void FillRecordingAVInfo(MythProgramInfo& programInfo, Myth::Stream *stream);
};
