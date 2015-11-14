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

#ifndef MYTHTYPES_H
#define	MYTHTYPES_H

#include "mythsharedptr.h"
#define MYTH_SHARED_PTR Myth::shared_ptr

#include <string>
#include <stdint.h>
#include <vector>
#include <map>
#include <ctime>

/**
 * @namespace Myth
 * @brief This is the main namespace that encloses all public classes
 */
namespace Myth
{
  uint32_t StringToId(const std::string& str);
  std::string IdToString(uint32_t id);
  time_t StringToTime(const std::string& isotime);
  std::string TimeToString(time_t time, bool utc = false);
  int StringToInt(const std::string& str);
  std::string IntToString(int i);

  typedef enum
  {
    RT_NotRecording   = 0,  // (0x00)
    RT_SingleRecord   = 1,  // (0x01)
    RT_DailyRecord,         // (0x02)
    RT_ChannelRecord,       // (0x03) obsolete since 76
    RT_AllRecord,           // (0x04)
    RT_WeeklyRecord,        // (0x05)
    RT_OneRecord,           // (0x06)
    RT_OverrideRecord,      // (0x07)
    RT_DontRecord,          // (0x08)
    RT_FindDailyRecord,     // (0x09) obsolete since 76
    RT_FindWeeklyRecord,    // (0x0a) obsolete since 76
    RT_TemplateRecord,      // (0x0b)
    RT_UNKNOWN  // Keep at last
  } RT_t;

  RT_t RuleTypeFromString(unsigned proto, const std::string& type);
  RT_t RuleTypeFromNum(unsigned proto, int type);
  const char *RuleTypeToString(unsigned proto, RT_t type);
  int RuleTypeToNum(unsigned proto, RT_t type);

  typedef enum
  {
    DI_InRecorded     = 0,  // (0x01)
    DI_InOldRecorded  = 1,  // (0x02)
    DI_InAll,               // (0x0F)
    DI_NewEpi,              // (0x10)
    DI_UNKNOWN  // Keep at last
  } DI_t;

  DI_t DupInFromString(unsigned proto, const std::string& type);
  DI_t DupInFromNum(unsigned proto, int type);
  const char *DupInToString(unsigned proto, DI_t type);
  int DupInToNum(unsigned proto, DI_t type);

  typedef enum
  {
    DM_CheckNone                    = 0,  // (0x01)
    DM_CheckSubtitle                = 1,  // (0x02)
    DM_CheckDescription,                  // (0x04)
    DM_CheckSubtitleAndDescription,       // (0x06)
    DM_CheckSubtitleThenDescription,      // (0x08)
    DM_UNKNOWN  // Keep at last
  } DM_t;

  DM_t DupMethodFromString(unsigned proto, const std::string& type);
  DM_t DupMethodFromNum(unsigned proto, int type);
  const char *DupMethodToString(unsigned proto, DM_t type);
  int DupMethodToNum(unsigned proto, DM_t type);

  typedef enum
  {
    ST_NoSearch       = 0,  // (0x00)
    ST_PowerSearch    = 1,  // (0x01)
    ST_TitleSearch,         // (0x02)
    ST_KeywordSearch,       // (0x03)
    ST_PeopleSearch,        // (0x04)
    ST_ManualSearch,        // (0x05)
    ST_UNKNOWN  // Keep at last
  } ST_t;

  ST_t SearchTypeFromString(unsigned proto, const std::string& type);
  ST_t SearchTypeFromNum(unsigned proto, int type);
  const char *SearchTypeToString(unsigned proto, ST_t type);
  int SearchTypeToNum(unsigned proto, ST_t type);

  typedef enum
  {
    CATT_CategoryNone     = 0,
    CATT_CategoryMovie,
    CATT_CategorySeries,
    CATT_CategorySports,
    CATT_CategoryTVShow,
    CATT_UNKNOWN  // Keep at last
  } CATT_t;

  CATT_t CategoryTypeFromString(unsigned proto, const std::string& type);
  CATT_t CategoryTypeFromNum(unsigned proto, int type);
  const char *CategoryTypeToString(unsigned proto, CATT_t type);
  int CategoryTypeToNum(unsigned proto, CATT_t type);

  typedef enum
  {
    FM_NewEpisode           = 0x001,
    FM_IdentifiableEpisode  = 0x002,
    FM_FirstShowing         = 0x004,
    FM_PrimeTime            = 0x008,
    FM_CommercialFree       = 0x010,
    FM_HighDefinition       = 0x020,
    FM_ThisEpisode          = 0x040,
    FM_ThisSeries           = 0x080,
    FM_ThisTime             = 0x100,
    FM_ThisDayAndTime       = 0x200,
    FM_ThisChannel          = 0x400
  } FM_t;

  typedef enum
  {
    EVENT_HANDLER_STATUS = 0,     // Internal event: Backend status change
    EVENT_HANDLER_TIMER,          // Internal event: Every cycle without event
    EVENT_UNKNOWN,
    EVENT_UPDATE_FILE_SIZE,
    EVENT_LIVETV_WATCH,
    EVENT_LIVETV_CHAIN,
    EVENT_DONE_RECORDING,
    EVENT_QUIT_LIVETV,
    EVENT_RECORDING_LIST_CHANGE,
    EVENT_SCHEDULE_CHANGE,
    EVENT_SIGNAL,
    EVENT_ASK_RECORDING,
    EVENT_CLEAR_SETTINGS_CACHE,
    EVENT_GENERATED_PIXMAP,
    EVENT_SYSTEM_EVENT,
  } EVENT_t;

  typedef enum
  {
    WHENCE_SET = 0,
    WHENCE_CUR = 1,
    WHENCE_END = 2,
  } WHENCE_t;

  typedef enum
  {
    RS_TUNING                 = -10,
    RS_FAILED                 = -9,
    RS_TUNER_BUSY             = -8,
    RS_LOW_DISKSPACE          = -7,
    RS_CANCELLED              = -6,
    RS_MISSED                 = -5,
    RS_ABORTED                = -4,
    RS_RECORDED               = -3,
    RS_RECORDING              = -2,
    RS_WILL_RECORD            = -1,
    RS_UNKNOWN                = 0,
    RS_DONT_RECORD            = 1,
    RS_PREVIOUS_RECORDING     = 2,
    RS_CURRENT_RECORDING      = 3,
    RS_EARLIER_RECORDING      = 4,
    RS_TOO_MANY_RECORDINGS    = 5,
    RS_NOT_LISTED             = 6,
    RS_CONFLICT               = 7,
    RS_LATER_SHOWING          = 8,
    RS_REPEAT                 = 9,
    RS_INACTIVE               = 10,
    RS_NEVER_RECORD           = 11,
    RS_OFFLINE                = 12,
    RS_OTHER_SHOWING          = 13,
  } RS_t;

  RS_t RecStatusFromString(unsigned proto, const std::string& type);
  RS_t RecStatusFromNum(unsigned proto, int type);
  const char *RecStatusToString(unsigned proto, RS_t type);
  int RecStatusToNum(unsigned proto, RS_t type);

  struct ItemList
  {
    uint32_t            count;
    uint32_t            protoVer;

    ItemList()
    : count(0)
    , protoVer(0)
    {}
  };

  typedef std::vector<std::string> StringList;
  typedef MYTH_SHARED_PTR<StringList> StringListPtr;

  struct Version
  {
    std::string         version;
    uint32_t            protocol;
    uint32_t            schema;

    Version()
    : protocol(0)
    , schema(0)
    {}
  };

  typedef MYTH_SHARED_PTR<Version> VersionPtr;

  struct Setting
  {
    std::string         key;
    std::string         value;
  };

  typedef MYTH_SHARED_PTR<Setting> SettingPtr;
  typedef std::map<std::string, SettingPtr> SettingMap;
  typedef MYTH_SHARED_PTR<SettingMap> SettingMapPtr;

  struct Artwork
  {
    std::string         url;
    std::string         fileName;
    std::string         storageGroup;
    std::string         type;
  };

  typedef MYTH_SHARED_PTR<Artwork> ArtworkPtr;
  typedef std::vector<ArtworkPtr> ArtworkList;
  typedef MYTH_SHARED_PTR<ArtworkList> ArtworkListPtr;

  struct Channel
  {
    uint32_t            chanId;
    std::string         chanNum;
    std::string         callSign;
    std::string         iconURL;
    std::string         channelName;
    uint32_t            mplexId;
    std::string         commFree;
    std::string         chanFilters;
    uint32_t            sourceId;
    uint32_t            inputId;
    bool                visible;

    Channel()
    : chanId(0)
    , mplexId(0)
    , sourceId(0)
    , inputId(0)
    , visible(true)
    {}
  };

  typedef MYTH_SHARED_PTR<Channel> ChannelPtr;
  typedef std::vector<ChannelPtr> ChannelList;
  typedef MYTH_SHARED_PTR<ChannelList> ChannelListPtr;

  struct Recording
  {
    uint32_t            recordId;
    int32_t             priority;
    int8_t              status;
    uint32_t            encoderId;
    uint8_t             recType;
    uint8_t             dupInType;
    uint8_t             dupMethod;
    time_t              startTs;
    time_t              endTs;
    std::string         profile;
    std::string         recGroup;
    std::string         storageGroup;
    std::string         playGroup;
    uint32_t            recordedId; // Since proto 82

    Recording()
    : recordId(0)
    , priority(0)
    , status(0)
    , encoderId(0)
    , recType(0)
    , dupInType(DI_InRecorded)
    , dupMethod(DM_CheckNone)
    , startTs(0)
    , endTs(0)
    , recordedId(0)
    {}
  };

  typedef MYTH_SHARED_PTR<Recording> RecordingPtr;
  typedef std::vector<RecordingPtr> RecordingList;
  typedef MYTH_SHARED_PTR<RecordingList> RecordingListPtr;

  struct Program
  {
    time_t                  startTime;
    time_t                  endTime;
    std::string             title;
    std::string             subTitle;
    std::string             description;
    uint16_t                season;
    uint16_t                episode;
    std::string             category;
    std::string             catType;
    std::string             hostName;
    std::string             fileName;
    int64_t                 fileSize;
    bool                    repeat;
    uint32_t                programFlags;
    std::string             seriesId;
    std::string             programId;
    std::string             inetref;
    time_t                  lastModified;
    std::string             stars;
    time_t                  airdate;
    uint16_t                audioProps;
    uint16_t                videoProps;
    uint16_t                subProps;
    Channel                 channel;
    Recording               recording;
    std::vector<Artwork>    artwork;

    Program()
    : startTime(0)
    , endTime(0)
    , season(0)
    , episode(0)
    , fileSize(0)
    , repeat(false)
    , programFlags(0)
    , lastModified(0)
    , airdate(0)
    , audioProps(0)
    , videoProps(0)
    , subProps(0)
    {}
  };

  typedef MYTH_SHARED_PTR<Program> ProgramPtr;
  typedef std::vector<ProgramPtr> ProgramList;
  typedef MYTH_SHARED_PTR<ProgramList> ProgramListPtr;
  typedef std::map<time_t, ProgramPtr> ProgramMap;
  typedef MYTH_SHARED_PTR<ProgramMap> ProgramMapPtr;

  struct CaptureCard
  {
    uint32_t            cardId;
    std::string         cardType;
    std::string         hostName;

    CaptureCard()
    : cardId(0)
    {}
  };

  typedef MYTH_SHARED_PTR<CaptureCard> CaptureCardPtr;
  typedef std::vector<CaptureCardPtr> CaptureCardList;
  typedef MYTH_SHARED_PTR<CaptureCardList> CaptureCardListPtr;

  struct CardInput
  {
    uint32_t            inputId;
    uint32_t            cardId;
    uint32_t            sourceId;
    uint32_t            mplexId;
    std::string         inputName;
    uint8_t             liveTVOrder;

    CardInput()
    : inputId(0)
    , cardId(0)
    , sourceId(0)
    , mplexId(0)
    , liveTVOrder(0)
    {}
  };

  typedef MYTH_SHARED_PTR<CardInput> CardInputPtr;
  typedef std::vector<CardInputPtr> CardInputList;
  typedef MYTH_SHARED_PTR<CardInputList> CardInputListPtr;

  struct VideoSource
  {
    uint32_t            sourceId;
    std::string         sourceName;

    VideoSource()
    : sourceId(0)
    {}
  };

  typedef MYTH_SHARED_PTR<VideoSource> VideoSourcePtr;
  typedef std::vector<VideoSourcePtr> VideoSourceList;
  typedef MYTH_SHARED_PTR<VideoSourceList> VideoSourceListPtr;

  struct RecordSchedule
  {
    uint32_t            recordId;
    std::string         title;
    std::string         subtitle;
    std::string         description;
    std::string         category;
    time_t              startTime;
    time_t              endTime;
    std::string         seriesId;
    std::string         programId;
    uint32_t            chanId;
    std::string         callSign;
    int8_t              findDay;
    std::string         findTime;
    uint32_t            parentId;
    bool                inactive;
    uint16_t            season;
    uint16_t            episode;
    std::string         inetref;
    std::string         type;
    RT_t                type_t;
    std::string         searchType;
    ST_t                searchType_t;
    int8_t              recPriority;
    uint32_t            preferredInput;
    uint8_t             startOffset;
    uint8_t             endOffset;
    std::string         dupMethod;
    DM_t                dupMethod_t;
    std::string         dupIn;
    DI_t                dupIn_t;
    uint32_t            filter;
    std::string         recProfile;
    std::string         recGroup;
    std::string         storageGroup;
    std::string         playGroup;
    bool                autoExpire;
    uint32_t            maxEpisodes;
    bool                maxNewest;
    bool                autoCommflag;
    bool                autoTranscode;
    bool                autoMetaLookup;
    bool                autoUserJob1;
    bool                autoUserJob2;
    bool                autoUserJob3;
    bool                autoUserJob4;
    uint32_t            transcoder;
    time_t              nextRecording;
    time_t              lastRecorded;
    time_t              lastDeleted;
    uint32_t            averageDelay;

    RecordSchedule()
    : recordId(0)
    , startTime(0)
    , endTime(0)
    , chanId(0)
    , findDay(0)
    , parentId(0)
    , inactive(false)
    , season(0)
    , episode(0)
    , type_t(RT_NotRecording)
    , searchType_t(ST_NoSearch)
    , recPriority(0)
    , preferredInput(0)
    , startOffset(0)
    , endOffset(0)
    , dupMethod_t(DM_CheckNone)
    , dupIn_t(DI_InRecorded)
    , filter(0)
    , autoExpire(false)
    , maxEpisodes(0)
    , maxNewest(false)
    , autoCommflag(false)
    , autoTranscode(false)
    , autoMetaLookup(false)
    , autoUserJob1(false)
    , autoUserJob2(false)
    , autoUserJob3(false)
    , autoUserJob4(false)
    , transcoder(0)
    , nextRecording(0)
    , lastRecorded(0)
    , lastDeleted(0)
    , averageDelay(0)
    {}
  };

  typedef MYTH_SHARED_PTR<RecordSchedule> RecordSchedulePtr;
  typedef std::vector<RecordSchedulePtr> RecordScheduleList;
  typedef MYTH_SHARED_PTR<RecordScheduleList> RecordScheduleListPtr;

  struct SignalStatus
  {
    bool    lock;
    int     signal;
    int     snr;
    long    ber;
    long    ucb;

    SignalStatus()
    : lock(false)
    , signal(0)
    , snr(0)
    , ber(0)
    , ucb(0)
    {}
  };

  typedef MYTH_SHARED_PTR<SignalStatus> SignalStatusPtr;

  struct EventMessage
  {
    EVENT_t                   event;
    std::vector<std::string>  subject;
    ProgramPtr                program;
    SignalStatusPtr           signal;

    EventMessage()
    : event(EVENT_UNKNOWN)
    {}
  };

  typedef MYTH_SHARED_PTR<EventMessage> EventMessagePtr;

  struct StorageGroupFile
  {
    std::string               fileName;
    std::string               storageGroup;
    std::string               hostName;
    time_t                    lastModified;
    int64_t                   size;

    StorageGroupFile()
    : lastModified(0)
    , size(0)
    {}
  };

  typedef MYTH_SHARED_PTR<StorageGroupFile> StorageGroupFilePtr;

  typedef enum
  {
    MARK_CUT_END       = 0,
    MARK_CUT_START     = 1,
    MARK_BOOKMARK      = 2,
    MARK_BLANK_FRAME   = 3,
    MARK_COMM_START    = 4,
    MARK_COMM_END      = 5,
    MARK_GOP_START     = 6,
    MARK_KEYFRAME      = 7,
    MARK_SCENE_CHANGE  = 8,
    MARK_GOP_BYFRAME   = 9,
    MARK_ASPECT_1_1    = 10,
    MARK_ASPECT_4_3    = 11,
    MARK_ASPECT_16_9   = 12,
    MARK_ASPECT_2_21_1 = 13,
    MARK_ASPECT_CUSTOM = 14,
    MARK_VIDEO_WIDTH   = 30,
    MARK_VIDEO_HEIGHT  = 31,
    MARK_VIDEO_RATE    = 32,
    MARK_DURATION_MS   = 33,
    MARK_TOTAL_FRAMES  = 34,
  } MARK_t;

  struct Mark
  {
    MARK_t                    markType;
    int64_t                   markValue;

    Mark()
    : markType(MARK_CUT_END)
    , markValue(0)
    {}
  };

  typedef MYTH_SHARED_PTR<Mark> MarkPtr;
  typedef std::vector<MarkPtr> MarkList;
  typedef MYTH_SHARED_PTR<MarkList> MarkListPtr;
}

#endif	/* MYTHTYPES_H */
