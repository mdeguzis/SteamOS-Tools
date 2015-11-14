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

#include "mythtypes.h"
#include "private/builtin.h"

using namespace Myth;

///////////////////////////////////////////////////////////////////////////////
////
//// Helpers
////

uint32_t Myth::StringToId(const std::string& str)
{
  uint32_t id = 0;
  string_to_uint32(str.c_str(), &id);
  return id;
}

std::string Myth::IdToString(uint32_t id)
{
  char buf[32];
  *buf = '\0';
  uint32_to_string(id, buf);
  return std::string(buf);
}

time_t Myth::StringToTime(const std::string& isotime)
{
  time_t time = INVALID_TIME;
  string_to_time(isotime.c_str(), &time);
  return time;
}

std::string Myth::TimeToString(time_t time, bool utc)
{
  if (utc)
  {
    char buf[TIMESTAMP_UTC_LEN + 1];
    *buf = '\0';
    time_to_iso8601utc(time, buf);
    return std::string(buf);
  }
  else
  {
    char buf[TIMESTAMP_LEN + 1];
    *buf = '\0';
    time_to_iso8601(time, buf);
    return std::string(buf);
  }
}

int Myth::StringToInt(const std::string& str)
{
  int32_t i = 0;
  string_to_int32(str.c_str(), &i);
  return (int)i;
}

std::string Myth::IntToString(int i)
{
  char buf[32];
  *buf = '\0';
  int32_to_string(i, buf);
  return std::string(buf);
}

///////////////////////////////////////////////////////////////////////////////
////
//// Generic mapper
////

typedef struct
{
  unsigned    protoVer;
  int         tVal;
  int         iVal;
  const char  *sVal;
} protoref_t;

static int __tValFromString(protoref_t *map, unsigned sz, unsigned proto, const std::string& sVal, int unk)
{
  for (unsigned i = 0; i < sz; ++i)
  {
    if (proto >= map[i].protoVer && sVal.compare(map[i].sVal) == 0)
      return map[i].tVal;
  }
  return unk;
}

static int __tValFromNum(protoref_t *map, unsigned sz, unsigned proto, int iVal, int unk)
{
  for (unsigned i = 0; i < sz; ++i)
  {
    if (proto >= map[i].protoVer && iVal == map[i].iVal)
      return map[i].tVal;
  }
  return unk;
}

static const char *__tValToString(protoref_t *map, unsigned sz, unsigned proto, int tVal, const char *unk)
{
  for (unsigned i = 0; i < sz; ++i)
  {
    if (proto >= map[i].protoVer && tVal == map[i].tVal)
      return map[i].sVal;
  }
  return unk;
}

static int __tValToNum(protoref_t *map, unsigned sz, unsigned proto, int tVal, int unk)
{
  for (unsigned i = 0; i < sz; ++i)
  {
    if (proto >= map[i].protoVer && tVal == map[i].tVal)
      return map[i].iVal;
  }
  return unk;
}

///////////////////////////////////////////////////////////////////////////////
////
//// ruleType mapper
////

static protoref_t ruleType[] =
{
  { 79, RT_TemplateRecord,    11, "Recording Template" },
  { 79, RT_NotRecording,      0,  "Not Recording" },
  { 76, RT_OneRecord,         6,  "Record One" },
  { 75, RT_SingleRecord,      1,  "Single Record" },
  { 75, RT_DailyRecord,       2,  "Record Daily" },
  { 75, RT_ChannelRecord,     3,  "Channel Record" },
  { 75, RT_AllRecord,         4,  "Record All" },
  { 75, RT_WeeklyRecord,      5,  "Record Weekly" },
  { 75, RT_OneRecord,         6,  "Find One" },
  { 75, RT_OverrideRecord,    7,  "Override Recording" },
  { 75, RT_DontRecord,        8,  "Do not Record" },
  { 75, RT_FindDailyRecord,   9,  "Find Daily" },
  { 75, RT_FindWeeklyRecord,  10, "Find Weekly" },
  { 75, RT_TemplateRecord,    11, "Not Recording" },
  { 75, RT_NotRecording,      0,  "Not Recording" },
};

RT_t Myth::RuleTypeFromString(unsigned proto, const std::string& type)
{
  static unsigned sz = sizeof(ruleType) / sizeof(protoref_t);
  return (RT_t)__tValFromString(ruleType, sz, proto, type, (int)RT_UNKNOWN);
}

RT_t Myth::RuleTypeFromNum(unsigned proto, int type)
{
  static unsigned sz = sizeof(ruleType) / sizeof(protoref_t);
  return (RT_t)__tValFromNum(ruleType, sz, proto, type, (int)RT_UNKNOWN);
}

const char *Myth::RuleTypeToString(unsigned proto, RT_t type)
{
  static unsigned sz = sizeof(ruleType) / sizeof(protoref_t);
  return __tValToString(ruleType, sz, proto, (int)type, "");
}

int Myth::RuleTypeToNum(unsigned proto, RT_t type)
{
  static unsigned sz = sizeof(ruleType) / sizeof(protoref_t);
  return __tValToNum(ruleType, sz, proto, (int)type, 0);
}

///////////////////////////////////////////////////////////////////////////////
////
//// dupIn mapper
////

static protoref_t dupIn[] =
{
  { 75, DI_InRecorded,    0x01, "Current Recordings" },
  { 75, DI_InOldRecorded, 0x02, "Previous Recordings" },
  { 75, DI_InAll,         0x0F, "All Recordings" },
  { 75, DI_NewEpi,        0x10, "New Episodes Only" },
};

DI_t Myth::DupInFromString(unsigned proto, const std::string& type)
{
  static unsigned sz = sizeof(dupIn) / sizeof(protoref_t);
  return (DI_t)__tValFromString(dupIn, sz, proto, type, (int)DI_UNKNOWN);
}

DI_t Myth::DupInFromNum(unsigned proto, int type)
{
  static unsigned sz = sizeof(dupIn) / sizeof(protoref_t);
  return (DI_t)__tValFromNum(dupIn, sz, proto, type, (int)DI_UNKNOWN);
}

const char *Myth::DupInToString(unsigned proto, DI_t type)
{
  static unsigned sz = sizeof(dupIn) / sizeof(protoref_t);
  return __tValToString(dupIn, sz, proto, (int)type, "");
}

int Myth::DupInToNum(unsigned proto, DI_t type)
{
  static unsigned sz = sizeof(dupIn) / sizeof(protoref_t);
  return __tValToNum(dupIn, sz, proto, (int)type, 0);
}

///////////////////////////////////////////////////////////////////////////////
////
//// dupMethod mapper
////

static protoref_t dupMethod[] =
{
  { 75, DM_CheckNone,                     0x01, "None" },
  { 75, DM_CheckSubtitle,                 0x02, "Subtitle" },
  { 75, DM_CheckDescription,              0x04, "Description" },
  { 75, DM_CheckSubtitleAndDescription,   0x06, "Subtitle and Description" },
  { 75, DM_CheckSubtitleThenDescription,  0x08, "Subtitle then Description" },
};

DM_t Myth::DupMethodFromString(unsigned proto, const std::string& type)
{
  static unsigned sz = sizeof(dupMethod) / sizeof(protoref_t);
  return (DM_t)__tValFromString(dupMethod, sz, proto, type, (int)DM_UNKNOWN);
}

DM_t Myth::DupMethodFromNum(unsigned proto, int type)
{
  static unsigned sz = sizeof(dupMethod) / sizeof(protoref_t);
  return (DM_t)__tValFromNum(dupMethod, sz, proto, type, (int)DM_UNKNOWN);
}

const char *Myth::DupMethodToString(unsigned proto, DM_t type)
{
  static unsigned sz = sizeof(dupMethod) / sizeof(protoref_t);
  return __tValToString(dupMethod, sz, proto, (int)type, "");
}

int Myth::DupMethodToNum(unsigned proto, DM_t type)
{
  static unsigned sz = sizeof(dupMethod) / sizeof(protoref_t);
  return __tValToNum(dupMethod, sz, proto, (int)type, 0);
}

///////////////////////////////////////////////////////////////////////////////
////
//// searchType mapper
////

static protoref_t searchType[] =
{
  { 75, ST_NoSearch,      0,  "None" },
  { 75, ST_PowerSearch,   1,  "Power Search" },
  { 75, ST_TitleSearch,   2,  "Title Search" },
  { 75, ST_KeywordSearch, 3,  "Keyword Search" },
  { 75, ST_PeopleSearch,  4,  "People Search" },
  { 75, ST_ManualSearch,  5,  "Manual Search" },
};

ST_t Myth::SearchTypeFromString(unsigned proto, const std::string& type)
{
  static unsigned sz = sizeof(searchType) / sizeof(protoref_t);
  return (ST_t)__tValFromString(searchType, sz, proto, type, (int)ST_UNKNOWN);
}

ST_t Myth::SearchTypeFromNum(unsigned proto, int type)
{
  static unsigned sz = sizeof(searchType) / sizeof(protoref_t);
  return (ST_t)__tValFromNum(searchType, sz, proto, type, (int)ST_UNKNOWN);
}

const char *Myth::SearchTypeToString(unsigned proto, ST_t type)
{
  static unsigned sz = sizeof(searchType) / sizeof(protoref_t);
  return __tValToString(searchType, sz, proto, (int)type, "");
}

int Myth::SearchTypeToNum(unsigned proto, ST_t type)
{
  static unsigned sz = sizeof(searchType) / sizeof(protoref_t);
  return __tValToNum(searchType, sz, proto, (int)type, 0);
}

///////////////////////////////////////////////////////////////////////////////
////
//// CategoryType mapper
////

static protoref_t categoryType[] =
{
  { 79, CATT_CategoryNone,      0,  "" },
  { 79, CATT_CategoryMovie,     1,  "movie" },
  { 79, CATT_CategorySeries,    2,  "series" },
  { 79, CATT_CategorySports,    3,  "sports" },
  { 79, CATT_CategoryTVShow,    4,  "tvshow" },
};

CATT_t Myth::CategoryTypeFromString(unsigned proto, const std::string& type)
{
  static unsigned sz = sizeof(categoryType) / sizeof(protoref_t);
  if (type.empty())
    return CATT_CategoryNone;
  return (CATT_t)__tValFromString(categoryType, sz, proto, type, (int)CATT_UNKNOWN);
}

CATT_t Myth::CategoryTypeFromNum(unsigned proto, int type)
{
  static unsigned sz = sizeof(categoryType) / sizeof(protoref_t);
  return (CATT_t)__tValFromNum(categoryType, sz, proto, type, (int)CATT_UNKNOWN);
}

const char *Myth::CategoryTypeToString(unsigned proto, CATT_t type)
{
  static unsigned sz = sizeof(categoryType) / sizeof(protoref_t);
  return __tValToString(categoryType, sz, proto, (int)type, "");
}

int Myth::CategoryTypeToNum(unsigned proto, CATT_t type)
{
  static unsigned sz = sizeof(categoryType) / sizeof(protoref_t);
  return __tValToNum(categoryType, sz, proto, (int)type, 0);
}

///////////////////////////////////////////////////////////////////////////////
////
//// recStatus mapper
////

static protoref_t recStatus[] =
{
  { 75, RS_TUNING,              -10,  "Tuning" },
  { 75, RS_FAILED,              -9,   "Failed" },
  { 75, RS_TUNER_BUSY,          -8,   "Tuner busy" },
  { 75, RS_LOW_DISKSPACE,       -7,   "Low disk space" },
  { 75, RS_CANCELLED,           -6,   "Cancelled" },
  { 75, RS_MISSED,              -5,   "Missed" },
  { 75, RS_ABORTED,             -4,   "Aborted" },
  { 75, RS_RECORDED,            -3,   "Recorded" },
  { 75, RS_RECORDING,           -2,   "Recording" },
  { 75, RS_WILL_RECORD,         -1,   "Will record" },
  { 75, RS_UNKNOWN,             0,    "Unknown" },
  { 75, RS_DONT_RECORD,         1,    "Don't record" },
  { 75, RS_PREVIOUS_RECORDING,  2,    "Previous recording" },
  { 75, RS_CURRENT_RECORDING,   3,    "Current recording" },
  { 75, RS_EARLIER_RECORDING,   4,    "Earlier recording" },
  { 75, RS_TOO_MANY_RECORDINGS, 5,    "Too many recordings" },
  { 75, RS_NOT_LISTED,          6,    "Not listed" },
  { 75, RS_CONFLICT,            7,    "Conflict" },
  { 75, RS_LATER_SHOWING,       8,    "Later showing" },
  { 75, RS_REPEAT,              9,    "Repeat" },
  { 75, RS_INACTIVE,            10,   "Inactive" },
  { 75, RS_NEVER_RECORD,        11,   "Never record" },
  { 75, RS_OFFLINE,             12,   "Offline" },
  { 75, RS_OTHER_SHOWING,       13,   "Other showing" },
};

RS_t Myth::RecStatusFromString(unsigned proto, const std::string& type)
{
  static unsigned sz = sizeof(recStatus) / sizeof(protoref_t);
  return (RS_t)__tValFromString(recStatus, sz, proto, type, (int)RT_UNKNOWN);
}

RS_t Myth::RecStatusFromNum(unsigned proto, int type)
{
  static unsigned sz = sizeof(recStatus) / sizeof(protoref_t);
  return (RS_t)__tValFromNum(recStatus, sz, proto, type, (int)RT_UNKNOWN);
}

const char *Myth::RecStatusToString(unsigned proto, RS_t type)
{
  static unsigned sz = sizeof(recStatus) / sizeof(protoref_t);
  return __tValToString(recStatus, sz, proto, (int)type, "");
}

int Myth::RecStatusToNum(unsigned proto, RS_t type)
{
  static unsigned sz = sizeof(recStatus) / sizeof(protoref_t);
  return __tValToNum(recStatus, sz, proto, (int)type, 0);
}
