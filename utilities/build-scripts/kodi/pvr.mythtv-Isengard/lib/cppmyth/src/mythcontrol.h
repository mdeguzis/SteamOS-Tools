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

#ifndef MYTHCONTROL_H
#define	MYTHCONTROL_H

#include "proto/mythprotomonitor.h"
#include "mythtypes.h"
#include "mythwsapi.h"

namespace Myth
{

  class Control
  {
  public:
    Control(const std::string& server, unsigned protoPort, unsigned wsapiPort, const std::string& wsapiSecurityPin);
    Control(const std::string& server, unsigned protoPort, unsigned wsapiPort, const std::string& wsapiSecurityPin, bool blockShutdown);
    ~Control();

    bool Open();
    void Close();
    bool IsOpen() { return m_monitor.IsOpen(); }
    bool HasHanging() const { return m_monitor.HasHanging(); }
    void CleanHanging() { m_monitor.CleanHanging(); }
    ProtoBase::ERROR_t GetProtoError() const { return m_monitor.GetProtoError(); }

    /**
     * @brief Check availability of API services
     * @return If unavailable then 0 else the backend protocol number
     */
    unsigned CheckService()
    {
      return m_wsapi.CheckService();
    }

    /**
     * @brief Query server host name
     * @return string
     */
    std::string GetServerHostName()
    {
      return m_wsapi.GetServerHostName();
    }

    /**
     * @brief Query server version infos
     * @return VersionPtr
     */
    VersionPtr GetVersion()
    {
      return m_wsapi.GetVersion();
    }

    /**
     * @brief Queries the backend for free space summary
     * @param total
     * @param used
     * @return bool
     */
    bool QueryFreeSpaceSummary(int64_t *total, int64_t *used)
    {
      return m_monitor.QueryFreeSpaceSummary(total, used);
    }

    /**
     * @brief Triggers preview image generation on the backend for a specified show
     * @param program
     * @return bool
     */
    bool QueryGenPixmap(const Program& program)
    {
      return m_monitor.QueryGenpixmap(program);
    }

    /**
     * @brief Ask the backend to cancel/continue next recording
     * @param rnum recorder Id
     * @param cancel
     * @return bool
     */
    bool CancelNextRecording(int rnum, bool cancel)
    {
      return m_monitor.CancelNextRecording(rnum, cancel);
    }

    /**
     * @brief Query setting by its key
     * @param key
     * @param hostname
     * @return SettingPtr
     */
    SettingPtr GetSetting(const std::string& key, const std::string hostname)
    {
      return m_wsapi.GetSetting(key, hostname);
    }

    /**
     * @brief Query setting by its key
     * @param key
     * @param myhost
     * @return SettingPtr
     */
    SettingPtr GetSetting(const std::string& key, bool myhost)
    {
      return m_wsapi.GetSetting(key, myhost);
    }

    /**
     * @brief Query all settings
     * @param hostname
     * @return SettingMapPtr
     */
    SettingMapPtr GetSettings(const std::string hostname)
    {
      return m_wsapi.GetSettings(hostname);
    }

    /**
     * @brief Query all settings
     * @param myhost
     * @return SettingMapPtr
     */
    SettingMapPtr GetSettings(bool myhost)
    {
      return m_wsapi.GetSettings(myhost);
    }

    /**
     * @brief Put setting
     * @param key
     * @param value
     * @param myhost
     * @return bool
     */
    bool PutSetting(const std::string& key, const std::string& value, bool myhost)
    {
      return m_wsapi.PutSetting(key, value, myhost);
    }

    /**
     * @brief Query backend server IP
     * @param hostName
     * @return string containing found IP or nil
     */
    std::string GetBackendServerIP(const std::string& hostName);

    /**
     * @brief Query backend server IP6
     * @param hostName
     * @return string containing found IP6 or nil
     */
    std::string GetBackendServerIP6(const std::string& hostName);

    /**
     * @brief Query backend server port for protocol commands
     * @param hostName
     * @return unsigned more than 0 else invalid
     */
    unsigned GetBackendServerPort(const std::string& hostName);

    /**
     * @brief Query information on all recorded programs
     * @param n
     * @param descending
     * @return ProgramListPtr
     */
    ProgramListPtr GetRecordedList(unsigned n = 0, bool descending = false)
    {
      return m_wsapi.GetRecordedList(n, descending);
    }

    /**
     * @brief Query information on a single item from recordings
     * @param chanid
     * @param recstartts
     * @return ProgramPtr
     */
    ProgramPtr GetRecorded(uint32_t chanid, time_t recstartts)
    {
      return m_wsapi.GetRecorded(chanid, recstartts);
    }

    /**
     * @brief Query information on a single item from recordings
     * @param recordedid
     * @return ProgramPtr
     */
    ProgramPtr GetRecorded(uint32_t recordedid)
    {
      return m_wsapi.GetRecorded(recordedid);
    }

    /**
     * @brief Update watched status for a recorded
     * @param chanid
     * @param recstartts
     * @return bool
     */
    bool UpdateRecordedWatchedStatus(const Program& program, bool watched)
    {
      WSServiceVersion_t wsv = m_wsapi.CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00060000)
        return m_wsapi.UpdateRecordedWatchedStatus(program.recording.recordedId, watched);
      return m_wsapi.UpdateRecordedWatchedStatus(program.channel.chanId, program.recording.startTs, watched);
    }

    /**
     * @brief Remove a Recording from the database and disk.
     * @param program
     * @param forceDelete (default false)
     * @param allowRerecord (default false)
     * @return bool
     */
    bool DeleteRecording(const Program& program, bool forceDelete = false, bool allowRerecord = false)
    {
      WSServiceVersion_t wsv = m_wsapi.CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00060000)
        return m_wsapi.DeleteRecording(program.recording.recordedId, forceDelete, allowRerecord);
      if (wsv.ranking >= 0x00020001)
        return m_wsapi.DeleteRecording(program.channel.chanId, program.recording.startTs, forceDelete, allowRerecord);
      return m_monitor.DeleteRecording(program, forceDelete, allowRerecord);
    }

    bool UndeleteRecording(const Program& program)
    {
      WSServiceVersion_t wsv = m_wsapi.CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00060000)
        return m_wsapi.UnDeleteRecording(program.recording.recordedId);
      if (wsv.ranking >= 0x00020001)
        return m_wsapi.UnDeleteRecording(program.channel.chanId, program.recording.startTs);
      return m_monitor.UndeleteRecording(program);
    }

    bool StopRecording(const Program& program)
    {
      return m_monitor.StopRecording(program);
    }

    /**
     * @brief Get all configured capture devices
     * @return CaptureCardListPtr
     */
    CaptureCardListPtr GetCaptureCardList()
    {
      return m_wsapi.GetCaptureCardList();
    }

    /**
     * @brief Get all video sources
     * @return VideoSourceListPtr
     */
    VideoSourceListPtr GetVideoSourceList()
    {
      return m_wsapi.GetVideoSourceList();
    }

    /**
     * @brief Get all configured channels for a video source
     * @param sourceid
     * @param onlyVisible (default true)
     * @return ChannelListPtr
     */
    ChannelListPtr GetChannelList(uint32_t sourceid, bool onlyVisible = true)
    {
      return m_wsapi.GetChannelList(sourceid, onlyVisible);
    }

    /**
     * @brief Retrieve a single channel, by channel id
     * @param chanid
     * @return ChannelPtr
     */
    ChannelPtr GetChannel(uint32_t chanid)
    {
      return m_wsapi.GetChannel(chanid);
    }

    /**
     * @brief Query the guide information for a particular time period and a channel
     * @param chanid
     * @param starttime
     * @param endtime
     * @return ProgramMapPtr
     */
    ProgramMapPtr GetProgramGuide(uint32_t chanid, time_t starttime, time_t endtime)
    {
      return m_wsapi.GetProgramGuide(chanid, starttime, endtime);
    }

    /**
     * @brief Query all configured recording rules
     * @return RecordScheduleListPtr
     */
    RecordScheduleListPtr GetRecordScheduleList()
    {
      return m_wsapi.GetRecordScheduleList();
    }

    /**
     * @brief Get a single recording rule, by record id
     * @param recordid
     * @return RecordSchedulePtr
     */
    RecordSchedulePtr GetRecordSchedule(uint32_t recordid)
    {
      return m_wsapi.GetRecordSchedule(recordid);
    }

    /**
     * @brief Add a new recording rule
     * @param record
     * @return status. On success Id is updated with the new.
     */
    bool AddRecordSchedule(RecordSchedule& record)
    {
      return m_wsapi.AddRecordSchedule(record);
    }

    /**
     * @brief Update a recording rule
     * @param record
     * @return status
     */
    bool UpdateRecordSchedule(RecordSchedule& record)
    {
      return m_wsapi.UpdateRecordSchedule(record);
    }

    /**
     * @brief Disable a recording rule
     * @param recordid
     * @return status
     */
    bool DisableRecordSchedule(uint32_t recordid)
    {
      return m_wsapi.DisableRecordSchedule(recordid);
    }

    /**
     * @brief Enable a recording rule
     * @param recordid
     * @return status
     */
    bool EnableRecordSchedule(uint32_t recordid)
    {
      return m_wsapi.EnableRecordSchedule(recordid);
    }

    /**
     * @brief Remove a recording rule
     * @param recordid
     * @return status
     */
    bool RemoveRecordSchedule(uint32_t recordid)
    {
      return m_wsapi.RemoveRecordSchedule(recordid);
    }

    /**
     * @brief Query information on all upcoming programs matching recording rules
     * @return ProgramListPtr
     */
    ProgramListPtr GetUpcomingList()
    {
      return m_wsapi.GetUpcomingList();
    }

    /**
     * @brief Query information on upcoming items which will not record due to conflicts
     * @return ProgramListPtr
     */
    ProgramListPtr GetConflictList()
    {
      return m_wsapi.GetConflictList();
    }

    /**
     * @brief Query information on recorded programs which are set to expire
     * @return ProgramListPtr
     */
    ProgramListPtr GetExpiringList()
    {
      return m_wsapi.GetExpiringList();
    }

    /**
     * @brief Get list of recording group
     * @return StringListPtr
     */
    StringListPtr GetRecGroupList()
    {
      return m_wsapi.GetRecGroupList();
    }

    /**
     * @brief Download a given file from a given storage group
     * @param filename
     * @param sgname
     * @return WSStreamPtr
     */
    WSStreamPtr GetFile(const std::string& filename, const std::string& sgname)
    {
      return m_wsapi.GetFile(filename, sgname);
    }

    /**
     * @brief Get the icon file for a given channel
     * @param chanid
     * @param width (default 0)
     * @param height (default 0)
     * @return WSStreamPtr
     */
    WSStreamPtr GetChannelIcon(uint32_t chanid, unsigned width = 0, unsigned height = 0)
    {
      return m_wsapi.GetChannelIcon(chanid, width, height);
    }

    /**
     * @brief Get, and optionally scale, an preview thumbnail for a given recording by timestamp, chanid and starttime
     * @param program
     * @param width (default 0)
     * @param height (default 0)
     * @return WSStreamPtr
     */
    WSStreamPtr GetPreviewImage(const Program& program, unsigned width = 0, unsigned height = 0)
    {
      return m_wsapi.GetPreviewImage(program.channel.chanId, program.recording.startTs, width, height);
    }

    /**
     * @brief Get, and optionally scale, an image file of a given type (coverart, banner, fanart) for a given recording's inetref and season number.
     * @param type
     * @param program
     * @param width (default 0)
     * @param height (default 0)
     * @return WSStreamPtr
     */
    WSStreamPtr GetRecordingArtwork(const std::string& type, const Program& program, unsigned width = 0, unsigned height = 0)
    {
      return m_wsapi.GetRecordingArtwork(type, program.inetref, program.season, width, height);
    }

    /**
     * @brief Get a list of artwork available for a recording by start time and channel id.
     * @param chanid
     * @param recstartts
     * @return ArtworkListPtr
     */
    ArtworkListPtr GetRecordingArtworkList(uint32_t chanid, time_t recstartts)
    {
      return m_wsapi.GetRecordingArtworkList(chanid, recstartts);
    }

    /**
     * @brief Refresh artwork available for a recording.
     * @param program
     * @return bool Return true if any artwork found
     */
    bool RefreshRecordedArtwork(Program& program);

    /**
     * @brief Request a set of cut list marks for a recording
     * @param program
     * @param unit 0 = Frame count, 1 = Position, 2 = Duration ms
     * @return MarkListPtr
     */
    MarkListPtr GetCutList(const Program& program, int unit = 0)
    {
      WSServiceVersion_t wsv = m_wsapi.CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00060001)
        return m_wsapi.GetRecordedCutList(program.recording.recordedId, unit);
      if (unit == 0)
        return m_monitor.GetCutList(program);
      else
        return MarkListPtr(new MarkList);
    }

    /**
     * @brief Request a set of commercial break marks for a recording
     * @param program
     * @param unit 0 = Frame count, 1 = Position, 2 = Duration ms
     * @return MarkListPtr
     */
    MarkListPtr GetCommBreakList(const Program& program, int unit = 0)
    {
      WSServiceVersion_t wsv = m_wsapi.CheckService(WS_Dvr);
      if (wsv.ranking >= 0x00060001)
        return m_wsapi.GetRecordedCommBreak(program.recording.recordedId, unit);
      if (unit == 0)
        return m_monitor.GetCommBreakList(program);
      else
        return MarkListPtr(new MarkList);
    }

    /**
     * @brief Prevents backend from shutting down until a the next call to AllowShutdown().
     * @return bool
     */
    bool BlockShutdown()
    {
      return m_monitor.BlockShutdown();
    }

    /**
     * @brief Allows backend to shut down again after a previous call to BlockShutdown().
     * @return bool
     */
    bool AllowShutdown()
    {
      return m_monitor.AllowShutdown();
    }

  private:
    ProtoMonitor m_monitor;
    WSAPI m_wsapi;

  };

}

#endif	/* MYTHCONTROL_H */
