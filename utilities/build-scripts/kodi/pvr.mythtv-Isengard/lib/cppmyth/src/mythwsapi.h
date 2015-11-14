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

#ifndef MYTHWSAPI_H
#define	MYTHWSAPI_H

#include "mythtypes.h"
#include "mythwsstream.h"

#define MYTH_API_VERSION_MIN_RANKING 0x00020000
#define MYTH_API_VERSION_MAX_RANKING 0x0005FFFF

namespace Myth
{

  namespace OS
  {
    class CMutex;
  }

  typedef enum
  {
    WS_Myth       = 0,
    WS_Capture    = 1,
    WS_Channel,
    WS_Guide,
    WS_Content,
    WS_Dvr,
    WS_INVALID, // Keep at last
  } WSServiceId_t;

  typedef struct
  {
    unsigned      major;
    unsigned      minor;
    unsigned      ranking;
  } WSServiceVersion_t;

  class WSAPI
  {
  public:
    WSAPI(const std::string& server, unsigned port, const std::string& securityPin);
    ~WSAPI();

    unsigned CheckService();
    WSServiceVersion_t CheckService(WSServiceId_t id);
    void InvalidateService();
    std::string GetServerHostName();
    VersionPtr GetVersion();
    std::string ResolveHostName(const std::string& hostname);

    /**
     * @brief GET Myth/GetSetting
     */
    SettingPtr GetSetting(const std::string& key, const std::string& hostname)
    {
      WSServiceVersion_t wsv = CheckService(WS_Myth);
      if (wsv.ranking >= 0x00050000) return GetSetting5_0(key, hostname);
      if (wsv.ranking >= 0x00020000) return GetSetting2_0(key, hostname);
      return SettingPtr();
    }

    /**
     * @brief GET Myth/GetSetting
     */
    SettingPtr GetSetting(const std::string& key, bool myhost);

    /**
     * @brief GET Myth/GetSetting
     */
    SettingMapPtr GetSettings(const std::string& hostname)
    {
      WSServiceVersion_t wsv = CheckService(WS_Myth);
      if (wsv.ranking >= 0x00050000) return GetSettings5_0(hostname);
      if (wsv.ranking >= 0x00020000) return GetSettings2_0(hostname);
      return SettingMapPtr(new SettingMap);
    }

    /**
     * @brief GET Myth/GetSetting
     */
    SettingMapPtr GetSettings(bool myhost);

    /**
     * @brief POST Myth/PutSetting
     */
    bool PutSetting(const std::string& key, const std::string& value, bool myhost)
    {
      WSServiceVersion_t wsv = CheckService(WS_Myth);
      if (wsv.ranking >= 0x00020000) return PutSetting2_0(key, value, myhost);
      return false;
    }

    /**
     * @brief GET Capture/GetCaptureCardList
     */
    CaptureCardListPtr GetCaptureCardList()
    {
      WSServiceVersion_t wsv = CheckService(WS_Capture);
      if (wsv.ranking >= 0x00010004) return GetCaptureCardList1_4();
      return CaptureCardListPtr(new CaptureCardList);
    }

    /**
     * @brief GET Channel/GetVideoSourceList
     */
    VideoSourceListPtr GetVideoSourceList()
    {
      WSServiceVersion_t wsv = CheckService(WS_Channel);
      if (wsv.ranking >= 0x00010002) return GetVideoSourceList1_2();
      return VideoSourceListPtr(new VideoSourceList);
    }

    /**
     * @brief GET Channel/GetChannelInfoList
     */
    ChannelListPtr GetChannelList(uint32_t sourceid, bool onlyVisible = true)
    {
      WSServiceVersion_t wsv = CheckService(WS_Channel);
      if (wsv.ranking >= 0x00010005) return GetChannelList1_5(sourceid, onlyVisible);
      if (wsv.ranking >= 0x00010002) return GetChannelList1_2(sourceid, onlyVisible);
      return ChannelListPtr(new ChannelList);
    };

    /**
     * @brief GET Channel/GetChannelInfo
     */
    ChannelPtr GetChannel(uint32_t chanid)
    {
      WSServiceVersion_t wsv = CheckService(WS_Channel);
      if (wsv.ranking >= 0x00010002) return GetChannel1_2(chanid);
      return ChannelPtr();
    };

    /**
     * @brief GET Guide/GetProgramGuide
     */
    ProgramMapPtr GetProgramGuide(uint32_t chanid, time_t starttime, time_t endtime)
    {
      WSServiceVersion_t wsv = CheckService(WS_Guide);
      if (wsv.ranking >= 0x00020002) return GetProgramList2_2(chanid, starttime, endtime);
      if (wsv.ranking >= 0x00010000) return GetProgramGuide1_0(chanid, starttime, endtime);
      return ProgramMapPtr(new ProgramMap);
    }

    /**
     * @brief GET Dvr/GetRecordedList
     */
    ProgramListPtr GetRecordedList(unsigned n = 0, bool descending = false)
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00010005) return GetRecordedList1_5(n, descending);
      return ProgramListPtr(new ProgramList);
    }

    /**
     * @brief GET Dvr/GetRecorded
     */
    ProgramPtr GetRecorded(uint32_t chanid, time_t recstartts)
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00010005) return GetRecorded1_5(chanid, recstartts);
      return ProgramPtr();
    }

    /**
     * @brief GET Dvr/GetRecorded
     */
    ProgramPtr GetRecorded(uint32_t recordedid)
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00060000) return GetRecorded6_0(recordedid);
      return ProgramPtr();
    }

    /**
     * @brief POST Dvr/UpdateRecordedWatchedStatus
     */
    bool UpdateRecordedWatchedStatus(uint32_t chanid, time_t recstartts, bool watched)
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00040005) return UpdateRecordedWatchedStatus4_5(chanid, recstartts, watched);
      return false;
    }

    /**
     * @brief POST Dvr/UpdateRecordedWatchedStatus
     */
    bool UpdateRecordedWatchedStatus(uint32_t recordedid, bool watched)
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00060000) return UpdateRecordedWatchedStatus6_0(recordedid, watched);
      return false;
    }

    /**
     * @brief POST Dvr/DeleteRecording
     */
    bool DeleteRecording(uint32_t chanid, time_t recstartts, bool forceDelete = false, bool allowRerecord = false)
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00020001) return DeleteRecording2_1(chanid, recstartts, forceDelete, allowRerecord);
      return false;
    }

    /**
     * @brief POST Dvr/DeleteRecording
     */
    bool DeleteRecording(uint32_t recordedid, bool forceDelete = false, bool allowRerecord = false)
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00060000) return DeleteRecording6_0(recordedid, forceDelete, allowRerecord);
      return false;
    }

    /**
     * @brief POST Dvr/UnDeleteRecording
     */
    bool UnDeleteRecording(uint32_t chanid, time_t recstartts)
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00020001) return UnDeleteRecording2_1(chanid, recstartts);
      return false;
    }

    /**
     * @brief POST Dvr/UnDeleteRecording
     */
    bool UnDeleteRecording(uint32_t recordedid)
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00060000) return UnDeleteRecording6_0(recordedid);
      return false;
    }

    /**
     * @brief GET Dvr/GetRecordScheduleList
     */
    RecordScheduleListPtr GetRecordScheduleList()
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00010005) return GetRecordScheduleList1_5();
      return RecordScheduleListPtr(new RecordScheduleList);
    }

    /**
     * @brief GET Dvr/GetRecordSchedule
     */
    RecordSchedulePtr GetRecordSchedule(uint32_t recordid)
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00010005) return GetRecordSchedule1_5(recordid);
      return RecordSchedulePtr();
    }

    /**
     * @brief POST Dvr/AddRecordSchedule
     */
    bool AddRecordSchedule(RecordSchedule& record)
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00010007) return AddRecordSchedule1_7(record);
      if (wsv.ranking >= 0x00010005) return AddRecordSchedule1_5(record);
      return false;
    }

    /**
     * @brief POST Dvr/UpdateRecordSchedule
     */
    bool UpdateRecordSchedule(RecordSchedule& record)
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00010007) return UpdateRecordSchedule1_7(record);
      return false;
    }

    /**
     * @brief POST Dvr/DisableRecordSchedule
     */
    bool DisableRecordSchedule(uint32_t recordid)
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00010005) return DisableRecordSchedule1_5(recordid);
      return false;
    }

    /**
     * @brief POST Dvr/EnableRecordSchedule
     */
    bool EnableRecordSchedule(uint32_t recordid)
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00010005) return EnableRecordSchedule1_5(recordid);
      return false;
    }

    /**
     * @brief POST Dvr/RemoveRecordSchedule
     */
    bool RemoveRecordSchedule(uint32_t recordid)
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00010005) return RemoveRecordSchedule1_5(recordid);
      return false;
    }

    /**
     * @brief GET Dvr/GetUpcomingList
     */
    ProgramListPtr GetUpcomingList()
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00020002) return GetUpcomingList2_2();
      if (wsv.ranking >= 0x00010005) return GetUpcomingList1_5();
      return ProgramListPtr(new ProgramList);
    }

    /**
     * @brief GET Dvr/GetConflictList
     */
    ProgramListPtr GetConflictList()
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00010005) return GetConflictList1_5();
      return ProgramListPtr(new ProgramList);
    }

    /**
     * @brief GET Dvr/GetExpiringList
     */
    ProgramListPtr GetExpiringList()
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00010005) return GetExpiringList1_5();
      return ProgramListPtr(new ProgramList);
    }

    /**
     * @brief GET Dvr/GetRecGroupList
     */
    StringListPtr GetRecGroupList()
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00010005) return GetRecGroupList1_5();
      return StringListPtr(new StringList);
    }

    /**
     * @brief GET Content/GetFile
     */
    WSStreamPtr GetFile(const std::string& filename, const std::string& sgname)
    {
      WSServiceVersion_t wsv = CheckService(WS_Content);
      if (wsv.ranking >= 0x00010020) return GetFile1_32(filename, sgname);
      return WSStreamPtr();
    }

    /**
     * @brief GET Guide/GetChannelIcon
     */
    WSStreamPtr GetChannelIcon(uint32_t chanid, unsigned width = 0, unsigned height = 0)
    {
      WSServiceVersion_t wsv = CheckService(WS_Content);
      if (wsv.ranking >= 0x00010020) return GetChannelIcon1_32(chanid, width, height);
      return WSStreamPtr();
    }

    /**
     * @brief GET Content/GetPreviewImage
     */
    WSStreamPtr GetPreviewImage(uint32_t chanid, time_t recstartts, unsigned width = 0, unsigned height = 0)
    {
      WSServiceVersion_t wsv = CheckService(WS_Content);
      if (wsv.ranking >= 0x00010020) return GetPreviewImage1_32(chanid, recstartts, width, height);
      return WSStreamPtr();
    }

    /**
     * @brief GET Content/GetRecordingArtwork
     */
    WSStreamPtr GetRecordingArtwork(const std::string& type, const std::string& inetref, uint16_t season, unsigned width = 0, unsigned height = 0)
    {
      WSServiceVersion_t wsv = CheckService(WS_Content);
      if (wsv.ranking >= 0x00010020) return GetRecordingArtwork1_32(type, inetref, season, width, height);
      return WSStreamPtr();
    }

    /**
     * @brief GET Content/GetRecordingArtworkList
     */
    ArtworkListPtr GetRecordingArtworkList(uint32_t chanid, time_t recstartts)
    {
      WSServiceVersion_t wsv = CheckService(WS_Content);
      if (wsv.ranking >= 0x00010020) return GetRecordingArtworkList1_32(chanid, recstartts);
      return ArtworkListPtr(new ArtworkList);
    }

    /**
     * @brief GET Dvr/GetRecordedCommBreak
     * @param recordedId
     * @param unit 0 = Frame count, 1 = Position, 2 = Duration ms
     * @return MarkListPtr
     */
    MarkListPtr GetRecordedCommBreak(uint32_t recordedId, int unit)
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00060001) return GetRecordedCommBreak6_1(recordedId, unit);
      return MarkListPtr(new MarkList);
    }

    /**
     * @brief GET Dvr/GetRecordedCutList
     * @param recordedId
     * @param unit 0 = Frame count, 1 = Position, 2 = Duration ms
     * @return MarkListPtr
     */
    MarkListPtr GetRecordedCutList(uint32_t recordedId, int unit)
    {
      WSServiceVersion_t wsv = CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00060001) return GetRecordedCutList6_1(recordedId, unit);
      return MarkListPtr(new MarkList);
    }

  private:
    OS::CMutex *m_mutex;
    std::string m_server;
    unsigned m_port;
    std::string m_securityPin;
    bool m_checked;
    Version m_version;
    std::string m_serverHostName;
    WSServiceVersion_t m_serviceVersion[WS_INVALID + 1];
    std::map<std::string, std::string> m_namedCache;

    // prevent copy
    WSAPI(const WSAPI&);
    WSAPI& operator=(const WSAPI&);

    bool InitWSAPI();
    bool GetServiceVersion(WSServiceId_t id, WSServiceVersion_t& version);
    bool CheckServerHostName2_0();
    bool CheckVersion2_0();

    SettingPtr GetSetting2_0(const std::string& key, const std::string& hostname);
    SettingPtr GetSetting5_0(const std::string& key, const std::string& hostname);
    SettingMapPtr GetSettings2_0(const std::string& hostname);
    SettingMapPtr GetSettings5_0(const std::string& hostname);
    bool PutSetting2_0(const std::string& key, const std::string& value, bool myhost);

    CaptureCardListPtr GetCaptureCardList1_4();

    VideoSourceListPtr GetVideoSourceList1_2();
    ChannelListPtr GetChannelList1_2(uint32_t sourceid, bool onlyVisible);
    ChannelListPtr GetChannelList1_5(uint32_t sourceid, bool onlyVisible);
    ChannelPtr GetChannel1_2(uint32_t chanid);

    ProgramMapPtr GetProgramGuide1_0(uint32_t chanid, time_t starttime, time_t endtime);
    ProgramMapPtr GetProgramList2_2(uint32_t chanid, time_t starttime, time_t endtime);

    ProgramListPtr GetRecordedList1_5(unsigned n, bool descending);
    ProgramPtr GetRecorded1_5(uint32_t chanid, time_t recstartts);
    ProgramPtr GetRecorded6_0(uint32_t recordedid);
    bool DeleteRecording2_1(uint32_t chanid, time_t recstartts, bool forceDelete, bool allowRerecord);
    bool DeleteRecording6_0(uint32_t recordedid, bool forceDelete, bool allowRerecord);
    bool UnDeleteRecording2_1(uint32_t chanid, time_t recstartts);
    bool UnDeleteRecording6_0(uint32_t recordedid);
    bool UpdateRecordedWatchedStatus4_5(uint32_t chanid, time_t recstartts, bool watched);
    bool UpdateRecordedWatchedStatus6_0(uint32_t recordedid, bool watched);
    MarkListPtr GetRecordedCommBreak6_1(uint32_t recordedid, int unit);
    MarkListPtr GetRecordedCutList6_1(uint32_t recordedid, int unit);

    RecordScheduleListPtr GetRecordScheduleList1_5();
    RecordSchedulePtr GetRecordSchedule1_5(uint32_t recordid);
    bool AddRecordSchedule1_5(RecordSchedule& record);
    bool AddRecordSchedule1_7(RecordSchedule& record);
    bool UpdateRecordSchedule1_7(RecordSchedule& record);
    bool DisableRecordSchedule1_5(uint32_t recordid);
    bool EnableRecordSchedule1_5(uint32_t recordid);
    bool RemoveRecordSchedule1_5(uint32_t recordid);
    ProgramListPtr GetUpcomingList1_5();
    ProgramListPtr GetUpcomingList2_2();
    ProgramListPtr GetConflictList1_5();
    ProgramListPtr GetExpiringList1_5();
    StringListPtr GetRecGroupList1_5();

    WSStreamPtr GetFile1_32(const std::string& filename, const std::string& sgname);
    WSStreamPtr GetChannelIcon1_32(uint32_t chanid, unsigned width, unsigned height);
    WSStreamPtr GetPreviewImage1_32(uint32_t chanid, time_t recstartts, unsigned width, unsigned height);
    WSStreamPtr GetRecordingArtwork1_32(const std::string& type, const std::string& inetref, uint16_t season, unsigned width, unsigned height);
    ArtworkListPtr GetRecordingArtworkList1_32(uint32_t chanid, time_t recstartts);
  };

}

#endif	/* MYTHWSAPI_H */

