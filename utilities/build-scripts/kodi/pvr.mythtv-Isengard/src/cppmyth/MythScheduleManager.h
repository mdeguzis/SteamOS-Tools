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
 *  along with XBMC; see the file COPYING.  If not, see
 *  <http://www.gnu.org/licenses/>.
 *
 */

#include <mythcontrol.h>
#include "MythRecordingRule.h"
#include "MythProgramInfo.h"
#include "MythEPGInfo.h"

#include <platform/threads/mutex.h>

#include <vector>
#include <list>
#include <map>

class MythRecordingRuleNode;
typedef MYTH_SHARED_PTR<MythRecordingRuleNode> RecordingRuleNodePtr;
typedef std::vector<RecordingRuleNodePtr> TemplateRuleList;

typedef std::vector<MythRecordingRule> OverrideRuleList;

typedef MYTH_SHARED_PTR<MythProgramInfo> ScheduledPtr;
// Schedule element is pair < index of schedule , program of schedule >
typedef std::vector<std::pair<uint32_t, ScheduledPtr> > ScheduleList;

typedef struct
{
  bool        isRepeating;
  int         weekDays;
  const char  *marker;
} RuleMetadata;

class MythRecordingRuleNode
{
public:
  friend class MythScheduleManager;

  MythRecordingRuleNode(const MythRecordingRule &rule);

  bool IsOverrideRule() const;
  MythRecordingRule GetRule() const;
  MythRecordingRule GetMainRule() const;

  bool HasOverrideRules() const;
  OverrideRuleList GetOverrideRules() const;

  bool IsInactiveRule() const;

private:
  MythRecordingRule m_rule;
  MythRecordingRule m_mainRule;
  std::vector<MythRecordingRule> m_overrideRules;
};

class MythScheduleManager
{
public:
  enum MSM_ERROR {
    MSM_ERROR_FAILED = -1,
    MSM_ERROR_NOT_IMPLEMENTED = 0,
    MSM_ERROR_SUCCESS = 1
  };

  MythScheduleManager(const std::string& server, unsigned protoPort, unsigned wsapiPort, const std::string& wsapiSecurityPin);
  ~MythScheduleManager();

  // Called by GetTimers
  unsigned GetUpcomingCount() const;
  ScheduleList GetUpcomingRecordings();

  // Called by AddTimer
  MSM_ERROR ScheduleRecording(MythRecordingRule &rule);

  // Called by DeleteTimer
  MSM_ERROR DeleteRecording(uint32_t index);

  MSM_ERROR DisableRecording(uint32_t index);
  MSM_ERROR EnableRecording(uint32_t index);
  MSM_ERROR UpdateRecording(uint32_t index, MythRecordingRule &newrule);

  RecordingRuleNodePtr FindRuleById(uint32_t recordid) const;
  ScheduleList FindUpComingByRuleId(uint32_t recordid) const;
  ScheduledPtr FindUpComingByIndex(uint32_t index) const;

  bool OpenControl();
  void CloseControl();
  void Update();

  class VersionHelper
  {
  public:
    friend class MythScheduleManager;

    VersionHelper() {}
    virtual ~VersionHelper();
    virtual bool SameTimeslot(MythRecordingRule &first, MythRecordingRule &second) const = 0;
    virtual RuleMetadata GetMetadata(const MythRecordingRule &rule) const = 0;
    virtual MythRecordingRule NewFromTemplate(MythEPGInfo &epgInfo) = 0;
    virtual MythRecordingRule NewSingleRecord(MythEPGInfo &epgInfo) = 0;
    virtual MythRecordingRule NewDailyRecord(MythEPGInfo &epgInfo) = 0;
    virtual MythRecordingRule NewWeeklyRecord(MythEPGInfo &epgInfo) = 0;
    virtual MythRecordingRule NewChannelRecord(MythEPGInfo &epgInfo) = 0;
    virtual MythRecordingRule NewOneRecord(MythEPGInfo &epgInfo) = 0;
  };

  RuleMetadata GetMetadata(const MythRecordingRule &rule) const;
  MythRecordingRule NewFromTemplate(MythEPGInfo &epgInfo);
  MythRecordingRule NewSingleRecord(MythEPGInfo &epgInfo);
  MythRecordingRule NewDailyRecord(MythEPGInfo &epgInfo);
  MythRecordingRule NewWeeklyRecord(MythEPGInfo &epgInfo);
  MythRecordingRule NewChannelRecord(MythEPGInfo &epgInfo);
  MythRecordingRule NewOneRecord(MythEPGInfo &epgInfo);

  TemplateRuleList GetTemplateRules() const;

  bool ToggleShowNotRecording();

private:
  mutable PLATFORM::CMutex m_lock;
  Myth::Control *m_control;

  int m_protoVersion;
  VersionHelper *m_versionHelper;
  void Setup();

  uint32_t MakeIndex(const ScheduledPtr &scheduled) const;
  MythRecordingRule MakeDontRecord(const MythRecordingRule &rule, const ScheduledPtr &recording);
  MythRecordingRule MakeOverride(const MythRecordingRule &rule, const ScheduledPtr &recording);

  // The list of rule nodes
  typedef std::list<RecordingRuleNodePtr> NodeList;
  // To find a rule node by its key (recordId)
  typedef std::map<uint32_t, RecordingRuleNodePtr> NodeById;
  // Store and find up coming recordings by index
  typedef std::map<uint32_t, ScheduledPtr> RecordingList;
  // To find all indexes of schedule by rule Id : pair < Rule Id , index of schedule >
  typedef std::multimap<uint32_t, uint32_t> RecordingIndexByRuleId;

  NodeList m_rules;
  NodeById m_rulesById;
  RecordingList m_recordings;
  RecordingIndexByRuleId m_recordingIndexByRuleId;
  TemplateRuleList m_templates;

  bool m_showNotRecording;
};


///////////////////////////////////////////////////////////////////////////////
////
//// VersionHelper
////

inline MythScheduleManager::VersionHelper::~VersionHelper() {
}

// No helper

class MythScheduleHelperNoHelper : public MythScheduleManager::VersionHelper {
public:
  virtual bool SameTimeslot(MythRecordingRule &first, MythRecordingRule &second) const;
  virtual RuleMetadata GetMetadata(const MythRecordingRule &rule) const;
  virtual MythRecordingRule NewFromTemplate(MythEPGInfo &epgInfo);
  virtual MythRecordingRule NewSingleRecord(MythEPGInfo &epgInfo);
  virtual MythRecordingRule NewDailyRecord(MythEPGInfo &epgInfo);
  virtual MythRecordingRule NewWeeklyRecord(MythEPGInfo &epgInfo);
  virtual MythRecordingRule NewChannelRecord(MythEPGInfo &epgInfo);
  virtual MythRecordingRule NewOneRecord(MythEPGInfo &epgInfo);
};

// Base 0.26

class MythScheduleHelper75 : public MythScheduleHelperNoHelper {
public:
  MythScheduleHelper75(MythScheduleManager *manager, Myth::Control *control)
  : m_manager(manager)
  , m_control(control) {
  }
  virtual bool SameTimeslot(MythRecordingRule &first, MythRecordingRule &second) const;
  virtual RuleMetadata GetMetadata(const MythRecordingRule &rule) const;
  virtual MythRecordingRule NewFromTemplate(MythEPGInfo &epgInfo);
  virtual MythRecordingRule NewSingleRecord(MythEPGInfo &epgInfo);
  virtual MythRecordingRule NewDailyRecord(MythEPGInfo &epgInfo);
  virtual MythRecordingRule NewWeeklyRecord(MythEPGInfo &epgInfo);
  virtual MythRecordingRule NewChannelRecord(MythEPGInfo &epgInfo);
  virtual MythRecordingRule NewOneRecord(MythEPGInfo &epgInfo);
protected:
  MythScheduleManager *m_manager;
  Myth::Control *m_control;
};

// News in 0.27

class MythScheduleHelper76 : public MythScheduleHelper75 {
public:
  MythScheduleHelper76(MythScheduleManager *manager, Myth::Control *control)
  : MythScheduleHelper75(manager, control) {
  }
  virtual RuleMetadata GetMetadata(const MythRecordingRule &rule) const;
  virtual MythRecordingRule NewDailyRecord(MythEPGInfo &epgInfo);
  virtual MythRecordingRule NewWeeklyRecord(MythEPGInfo &epgInfo);
  virtual MythRecordingRule NewChannelRecord(MythEPGInfo &epgInfo);
  virtual MythRecordingRule NewOneRecord(MythEPGInfo &epgInfo);
};
