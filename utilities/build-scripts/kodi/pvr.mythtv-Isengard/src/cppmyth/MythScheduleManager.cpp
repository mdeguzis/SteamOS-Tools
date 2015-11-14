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

#include "MythScheduleManager.h"
#include "../client.h"
#include "../tools.h"

#include <cstdio>

using namespace ADDON;
using namespace PLATFORM;

enum
{
  METHOD_UNKNOWN = 0,
  METHOD_UPDATE_INACTIVE = 1,
  METHOD_CREATE_OVERRIDE = 2,
  METHOD_DELETE = 3,
  METHOD_DISCREET_UPDATE = 4,
  METHOD_FULL_UPDATE = 5
};

static uint_fast32_t hashvalue(uint_fast32_t maxsize, const char *value)
{
  uint_fast32_t h = 0, g;

  while (*value)
  {
    h = (h << 4) + *value++;
    if ((g = h & 0xF0000000L))
    {
      h ^= g >> 24;
    }
    h &= ~g;
  }

  return h % maxsize;
}


///////////////////////////////////////////////////////////////////////////////
////
//// MythRecordingRuleNode
////

MythRecordingRuleNode::MythRecordingRuleNode(const MythRecordingRule &rule)
  : m_rule(rule)
  , m_mainRule()
  , m_overrideRules()
{
}

bool MythRecordingRuleNode::IsOverrideRule() const
{
  return (m_rule.Type() == Myth::RT_DontRecord || m_rule.Type() == Myth::RT_OverrideRecord);
}

MythRecordingRule MythRecordingRuleNode::GetRule() const
{
  return m_rule;
}

MythRecordingRule MythRecordingRuleNode::GetMainRule() const
{
  if (this->IsOverrideRule())
    return m_mainRule;
  return m_rule;
}

bool MythRecordingRuleNode::HasOverrideRules() const
{
  return (!m_overrideRules.empty());
}

OverrideRuleList MythRecordingRuleNode::GetOverrideRules() const
{
  return m_overrideRules;
}

bool MythRecordingRuleNode::IsInactiveRule() const
{
  return m_rule.Inactive();
}


///////////////////////////////////////////////////////////////////////////////
////
//// MythScheduleManager
////

MythScheduleManager::MythScheduleManager(const std::string& server, unsigned protoPort, unsigned wsapiPort, const std::string& wsapiSecurityPin)
: m_lock()
, m_control(NULL)
, m_protoVersion(0)
, m_versionHelper(NULL)
, m_showNotRecording(false)
{
  m_control = new Myth::Control(server, protoPort, wsapiPort, wsapiSecurityPin);
  this->Update();
}

MythScheduleManager::~MythScheduleManager()
{
  SAFE_DELETE(m_versionHelper);
  SAFE_DELETE(m_control);
}

void MythScheduleManager::Setup()
{
  int old = m_protoVersion;
  m_protoVersion = m_control->CheckService();

  // On new connection the protocol version could change
  if (m_protoVersion != old)
  {
    SAFE_DELETE(m_versionHelper);
    if (m_protoVersion >= 76)
      m_versionHelper = new MythScheduleHelper76(this, m_control);
    else if (m_protoVersion >= 75)
      m_versionHelper = new MythScheduleHelper75(this, m_control);
    else
      m_versionHelper = new MythScheduleHelperNoHelper();
  }
}

uint32_t MythScheduleManager::MakeIndex(const ScheduledPtr &scheduled) const
{
  // Recordings must keep same identifier even after refreshing cache (cf Update).
  // Numeric hash of UID is used to make the constant numeric identifier.
  uint32_t index = (scheduled->RecordID() << 16) + hashvalue(0xFFFF, scheduled->UID().c_str());
  return index;
}

MythRecordingRule MythScheduleManager::MakeDontRecord(const MythRecordingRule& rule, const ScheduledPtr& recording)
{
  MythRecordingRule modifier = rule.DuplicateRecordingRule();
  // Do the same as backend even we know the modifier will be rejected for manual rule:
  // Don't know if this behavior is a bug issue or desired: cf libmythtv/recordingrule.cpp
  if (modifier.SearchType() != Myth::ST_ManualSearch)
    modifier.SetSearchType(Myth::ST_NoSearch);

  modifier.SetType(Myth::RT_DontRecord);
  modifier.SetParentID(modifier.RecordID());
  modifier.SetRecordID(0);
  modifier.SetInactive(false);
  // Assign recording info
  modifier.SetTitle(recording->Title());
  modifier.SetSubtitle(recording->Subtitle());
  modifier.SetDescription(recording->Description());
  modifier.SetChannelID(recording->ChannelID());
  modifier.SetCallsign(recording->Callsign());
  modifier.SetStartTime(recording->StartTime());
  modifier.SetEndTime(recording->EndTime());
  modifier.SetSeriesID(recording->SerieID());
  modifier.SetProgramID(recording->ProgramID());
  modifier.SetCategory(recording->Category());
  if (rule.InetRef().empty())
  {
    modifier.SetInerRef(recording->Inetref());
    modifier.SetSeason(recording->Season());
    modifier.SetEpisode(recording->Episode());
  }
  return modifier;
}

MythRecordingRule MythScheduleManager::MakeOverride(const MythRecordingRule& rule, const ScheduledPtr& recording)
{
  MythRecordingRule modifier = rule.DuplicateRecordingRule();
  // Do the same as backend even we know the modifier will be rejected for manual rule:
  // Don't know if this behavior is a bug issue or desired: cf libmythtv/recordingrule.cpp
  if (modifier.SearchType() != Myth::ST_ManualSearch)
    modifier.SetSearchType(Myth::ST_NoSearch);

  modifier.SetType(Myth::RT_OverrideRecord);
  modifier.SetParentID(modifier.RecordID());
  modifier.SetRecordID(0);
  modifier.SetInactive(false);
  // Assign recording info
  modifier.SetTitle(recording->Title());
  modifier.SetSubtitle(recording->Subtitle());
  modifier.SetDescription(recording->Description());
  modifier.SetChannelID(recording->ChannelID());
  modifier.SetCallsign(recording->Callsign());
  modifier.SetStartTime(recording->StartTime());
  modifier.SetEndTime(recording->EndTime());
  modifier.SetSeriesID(recording->SerieID());
  modifier.SetProgramID(recording->ProgramID());
  modifier.SetCategory(recording->Category());
  if (rule.InetRef().empty())
  {
    modifier.SetInerRef(recording->Inetref());
    modifier.SetSeason(recording->Season());
    modifier.SetEpisode(recording->Episode());
  }
  return modifier;
}

unsigned MythScheduleManager::GetUpcomingCount() const
{
  CLockObject lock(m_lock);
  return (unsigned)m_recordings.size();
}

ScheduleList MythScheduleManager::GetUpcomingRecordings()
{
  ScheduleList recordings;
  CLockObject lock(m_lock);
  for (RecordingList::iterator it = m_recordings.begin(); it != m_recordings.end(); ++it)
  {

    //Only include timers which have an inactive status if the user has requested it (flag m_showNotRecording)
    switch (it->second->Status())
    {
    //Upcoming recordings which are disabled due to being lower priority duplicates or already recorded
    case Myth::RS_EARLIER_RECORDING:  //will record earlier
    case Myth::RS_LATER_SHOWING:      //will record later
    case Myth::RS_CURRENT_RECORDING:  //Already in the current library
    case Myth::RS_PREVIOUS_RECORDING: //Previoulsy recorded but no longer in the library
      if (!m_showNotRecording)
      {
        XBMC->Log(LOG_DEBUG, "%s: Skipping %s:%s on %s because status %d and m_showNotRecording=%i", __FUNCTION__,
                  it->second->Title().c_str(), it->second->Subtitle().c_str(), it->second->ChannelName().c_str(), it->second->Status(), m_showNotRecording);
        continue;
      }
    default:
      break;
    }

    recordings.push_back(std::make_pair(it->first, it->second));
  }
  return recordings;
}

MythScheduleManager::MSM_ERROR MythScheduleManager::ScheduleRecording(MythRecordingRule &rule)
{
  // Don't schedule nil
  if (rule.Type() == Myth::RT_NotRecording)
    return MSM_ERROR_FAILED;

  if (!m_control->AddRecordSchedule(*(rule.GetPtr())))
    return MSM_ERROR_FAILED;

  //if (!m_con.UpdateSchedules(rule.RecordID()))
  //  return MSM_ERROR_FAILED;

  return MSM_ERROR_SUCCESS;
}

MythScheduleManager::MSM_ERROR MythScheduleManager::DeleteRecording(unsigned int index)
{
  CLockObject lock(m_lock);

  ScheduledPtr recording = this->FindUpComingByIndex(index);
  if (!recording)
    return MSM_ERROR_FAILED;

  RecordingRuleNodePtr node = this->FindRuleById(recording->RecordID());
  if (node)
  {
    XBMC->Log(LOG_DEBUG, "%s - %u : Found rule %u type %d", __FUNCTION__, index, (unsigned)node->m_rule.RecordID(), (int)node->m_rule.Type());

    // Delete override rules
    if (node->HasOverrideRules())
    {
      for (OverrideRuleList::iterator ito = node->m_overrideRules.begin(); ito != node->m_overrideRules.end(); ++ito)
      {
        XBMC->Log(LOG_DEBUG, "%s - %u : Found override rule %u type %d", __FUNCTION__, index, (unsigned)ito->RecordID(), (int)ito->Type());
        ScheduleList rec = this->FindUpComingByRuleId(ito->RecordID());
        for (ScheduleList::iterator itr = rec.begin(); itr != rec.end(); ++itr)
        {
          XBMC->Log(LOG_DEBUG, "%s - %u : Found override recording %s status %d", __FUNCTION__, index, itr->second->UID().c_str(), itr->second->Status());
          if (itr->second->Status() == Myth::RS_RECORDING || itr->second->Status() == Myth::RS_TUNING)
          {
            XBMC->Log(LOG_DEBUG, "%s - Stop recording %s", __FUNCTION__, itr->second->UID().c_str());
            m_control->StopRecording(*(itr->second->GetPtr()));
          }
        }
        XBMC->Log(LOG_DEBUG, "%s - Delete recording rule %u (modifier of rule %u)", __FUNCTION__, (unsigned)ito->RecordID(), (unsigned)node->m_rule.RecordID());
        if (!m_control->RemoveRecordSchedule(ito->RecordID()))
          XBMC->Log(LOG_ERROR, "%s - Delete recording rule failed", __FUNCTION__);
      }
    }

    // Delete main rule
    ScheduleList rec = this->FindUpComingByRuleId(node->m_rule.RecordID());
    for (ScheduleList::iterator itr = rec.begin(); itr != rec.end(); ++itr)
    {
      XBMC->Log(LOG_DEBUG, "%s - %u : Found recording %s status %d", __FUNCTION__, index, itr->second->UID().c_str(), itr->second->Status());
      if (itr->second->Status() == Myth::RS_RECORDING || itr->second->Status() == Myth::RS_TUNING)
      {
        XBMC->Log(LOG_DEBUG, "%s - Stop recording %s", __FUNCTION__, itr->second->UID().c_str());
        m_control->StopRecording(*(itr->second->GetPtr()));
      }
    }
    XBMC->Log(LOG_DEBUG, "%s - Delete recording rule %u", __FUNCTION__, node->m_rule.RecordID());
    if (!m_control->RemoveRecordSchedule(node->m_rule.RecordID()))
      XBMC->Log(LOG_ERROR, "%s - Delete recording rule failed", __FUNCTION__);

    //if (!m_con.UpdateSchedules(-1))
    //  return MSM_ERROR_FAILED;

    // Another client could delete the rule at the same time. Therefore always SUCCESS even if database delete fails.
    return MSM_ERROR_SUCCESS;
  }
  else
  {
    XBMC->Log(LOG_DEBUG, "%s - %u : No rule for recording %s status %d", __FUNCTION__, index, recording->UID().c_str(), recording->Status());
    if (recording->Status() == Myth::RS_RECORDING || recording->Status() == Myth::RS_TUNING)
    {
      XBMC->Log(LOG_DEBUG, "%s - Stop recording %s", __FUNCTION__, recording->UID().c_str());
      m_control->StopRecording(*(recording->GetPtr()));
      return MSM_ERROR_SUCCESS;
    }
  }

  return MSM_ERROR_NOT_IMPLEMENTED;
}

MythScheduleManager::MSM_ERROR MythScheduleManager::DisableRecording(unsigned int index)
{
  CLockObject lock(m_lock);

  ScheduledPtr recording = this->FindUpComingByIndex(index);
  if (!recording)
    return MSM_ERROR_FAILED;

  if (recording->Status() == Myth::RS_INACTIVE || recording->Status() == Myth::RS_DONT_RECORD)
    return MSM_ERROR_SUCCESS;

  RecordingRuleNodePtr node = this->FindRuleById(recording->RecordID());
  if (node)
  {
    XBMC->Log(LOG_DEBUG, "%s - %u : %s:%s on channel %s program %s",
              __FUNCTION__, index, recording->Title().c_str(), recording->Subtitle().c_str(), recording->Callsign().c_str(), recording->UID().c_str());
    XBMC->Log(LOG_DEBUG, "%s - %u : Found rule %u type %d with recording status %i",
              __FUNCTION__, index, (unsigned)node->m_rule.RecordID(), (int)node->m_rule.Type(), recording->Status());
    int method = METHOD_UNKNOWN;
    MythRecordingRule handle = node->m_rule.DuplicateRecordingRule();

    // Not recording. Simply inactivate the rule
    if (recording->Status() == Myth::RS_UNKNOWN)
    {
      method = METHOD_UPDATE_INACTIVE;
    }
    else
    {
      // Method depends of its rule type
      switch (node->m_rule.Type())
      {
      case Myth::RT_SingleRecord:
        switch (recording->Status())
        {
          case Myth::RS_RECORDING:
          case Myth::RS_TUNING:
            method = METHOD_DELETE;
            break;
          case Myth::RS_PREVIOUS_RECORDING:
          case Myth::RS_EARLIER_RECORDING:
            method = METHOD_CREATE_OVERRIDE;
            break;
          default:
            method = METHOD_UPDATE_INACTIVE;
            break;
        }
        break;
      case Myth::RT_NotRecording:
        method = METHOD_UPDATE_INACTIVE;
        break;
      case Myth::RT_OneRecord:
      case Myth::RT_ChannelRecord:
      case Myth::RT_AllRecord:
      case Myth::RT_DailyRecord:
      case Myth::RT_WeeklyRecord:
      case Myth::RT_FindDailyRecord:
      case Myth::RT_FindWeeklyRecord:
        method = METHOD_CREATE_OVERRIDE;
        break;
      case Myth::RT_OverrideRecord:
        method = METHOD_DELETE;
        break;
      default:
        break;
      }
    }

    XBMC->Log(LOG_DEBUG, "%s - %u : Dealing with the problem using method %i", __FUNCTION__, index, method);
    if (method == METHOD_UPDATE_INACTIVE)
    {
      handle.SetInactive(true);
      if (!m_control->UpdateRecordSchedule(*(handle.GetPtr())))
        return MSM_ERROR_FAILED;
      node->m_rule = handle; // sync node
      //if (!m_con.UpdateSchedules(handle.RecordID()))
      //  return MSM_ERROR_FAILED;
      return MSM_ERROR_SUCCESS;
    }
    if (method == METHOD_CREATE_OVERRIDE)
    {
      handle = MakeDontRecord(handle, recording);
      XBMC->Log(LOG_DEBUG, "%s - %u : Creating Override for %u (%s: %s) on %i (%s)"
                , __FUNCTION__, index, (unsigned)handle.ParentID(), handle.Title().c_str(),
                handle.Subtitle().c_str(), handle.ChannelID(), handle.Callsign().c_str());

      if (!m_control->AddRecordSchedule(*(handle.GetPtr())))
        return MSM_ERROR_FAILED;
      node->m_overrideRules.push_back(handle); // sync node
      //if (!m_con.UpdateSchedules(handle.RecordID()))
      //  return MSM_ERROR_FAILED;
      return MSM_ERROR_SUCCESS;
    }
    if (method == METHOD_DELETE)
    {
      return this->DeleteRecording(index);
    }
  }

  return MSM_ERROR_NOT_IMPLEMENTED;
}

MythScheduleManager::MSM_ERROR MythScheduleManager::EnableRecording(unsigned int index)
{
  CLockObject lock(m_lock);

  ScheduledPtr recording = this->FindUpComingByIndex(index);
  if (!recording)
    return MSM_ERROR_FAILED;

  RecordingRuleNodePtr node = this->FindRuleById(recording->RecordID());
  if (node)
  {
    XBMC->Log(LOG_DEBUG, "%s - %u : %s:%s on channel %s program %s",
              __FUNCTION__, index, recording->Title().c_str(), recording->Subtitle().c_str(), recording->Callsign().c_str(), recording->UID().c_str());
    XBMC->Log(LOG_DEBUG, "%s - %u : Found rule %u type %d disabled by status %i",
              __FUNCTION__, index, (unsigned)node->m_rule.RecordID(), (int)node->m_rule.Type(), recording->Status());
    int method = METHOD_UNKNOWN;
    MythRecordingRule handle = node->m_rule.DuplicateRecordingRule();

    switch (recording->Status())
    {
      case Myth::RS_UNKNOWN:
        // Not recording. Simply activate the rule
        method = METHOD_UPDATE_INACTIVE;
        break;
      case Myth::RS_NEVER_RECORD:
      case Myth::RS_PREVIOUS_RECORDING:
      case Myth::RS_EARLIER_RECORDING:
      case Myth::RS_CURRENT_RECORDING:
        // Add override to record anyway
        method = METHOD_CREATE_OVERRIDE;
        break;

      default:
        // Method depends of its rule type
        switch (node->m_rule.Type())
        {
          case Myth::RT_DontRecord:
          case Myth::RT_OverrideRecord:
            method = METHOD_DELETE;
            break;
          case Myth::RT_SingleRecord:
          case Myth::RT_NotRecording:
          case Myth::RT_OneRecord:
          case Myth::RT_ChannelRecord:
          case Myth::RT_AllRecord:
          case Myth::RT_DailyRecord:
          case Myth::RT_WeeklyRecord:
          case Myth::RT_FindDailyRecord:
          case Myth::RT_FindWeeklyRecord:
            // Is it inactive ? Try to enable rule
            method = METHOD_UPDATE_INACTIVE;
            break;
          default:
            break;
        }
        break;
    }

    XBMC->Log(LOG_DEBUG, "%s - %u : Dealing with the problem using method %i", __FUNCTION__, index, method);
    if (method == METHOD_UPDATE_INACTIVE)
    {
      handle.SetInactive(false);
      if (!m_control->UpdateRecordSchedule(*(handle.GetPtr())))
        return MSM_ERROR_FAILED;
      node->m_rule = handle; // sync node
      //if (!m_con.UpdateSchedules(handle.RecordID()))
      //  return MSM_ERROR_FAILED;
      return MSM_ERROR_SUCCESS;
    }
    if (method == METHOD_CREATE_OVERRIDE)
    {
      handle = MakeOverride(handle, recording);
      XBMC->Log(LOG_DEBUG, "%s - %u : Creating Override for %u (%s:%s) on %i (%s)"
                , __FUNCTION__, index, (unsigned)handle.ParentID(), handle.Title().c_str(),
                handle.Subtitle().c_str(), handle.ChannelID(), handle.Callsign().c_str());

      if (!m_control->AddRecordSchedule(*(handle.GetPtr())))
        return MSM_ERROR_FAILED;
      node->m_overrideRules.push_back(handle); // sync node
      //if (!m_con.UpdateSchedules(handle.RecordID()))
      //  return MSM_ERROR_FAILED;
      return MSM_ERROR_SUCCESS;
    }
    if (method == METHOD_DELETE)
    {
      return this->DeleteRecording(index);
    }
  }

  return MSM_ERROR_NOT_IMPLEMENTED;
}

MythScheduleManager::MSM_ERROR MythScheduleManager::UpdateRecording(unsigned int index, MythRecordingRule &newrule)
{
  CLockObject lock(m_lock);

  ScheduledPtr recording = this->FindUpComingByIndex(index);
  if (!recording)
    return MSM_ERROR_FAILED;

  RecordingRuleNodePtr node = this->FindRuleById(recording->RecordID());
  if (node)
  {
    XBMC->Log(LOG_DEBUG, "%s - %u : Found rule %u type %d and recording status %i",
              __FUNCTION__, index, (unsigned)node->m_rule.RecordID(), (int)node->m_rule.Type(), recording->Status());
    int method = METHOD_UNKNOWN;
    MythRecordingRule handle = node->m_rule.DuplicateRecordingRule();

    // Rule update method depends of current rule type:
    // - Updating override rule is limited.
    // - Enabled repeating rule must to be overriden.
    // - All others could be fully updated until it is recording.
    switch (node->m_rule.Type())
    {
    case Myth::RT_DontRecord:
    case Myth::RT_NotRecording:
    case Myth::RT_TemplateRecord:
      // Deny update
      method = METHOD_UNKNOWN;
      break;
    case Myth::RT_AllRecord:
    case Myth::RT_ChannelRecord:
    case Myth::RT_OneRecord:
    case Myth::RT_FindDailyRecord:
    case Myth::RT_FindWeeklyRecord:
    case Myth::RT_DailyRecord:
    case Myth::RT_WeeklyRecord:
      // When inactive we can replace with the new rule
      if (handle.Inactive())
      {
        method = METHOD_FULL_UPDATE;
      }
      // When active we create override rule
      else
      {
        // Only priority can be overriden
        if (newrule.Priority() != handle.Priority())
        {
          handle.SetPriority(newrule.Priority());
          method = METHOD_CREATE_OVERRIDE;
        }
        else
          method = METHOD_UNKNOWN;
      }
      break;
    case Myth::RT_OverrideRecord:
      // Only priority can be overriden
      handle.SetPriority(newrule.Priority());
      method = METHOD_DISCREET_UPDATE;
      break;
    case Myth::RT_SingleRecord:
      if (recording->Status() == Myth::RS_RECORDING || recording->Status() == Myth::RS_TUNING)
      {
        // Discreet update
        handle.SetEndTime(newrule.EndTime());
        handle.SetEndOffset(newrule.EndOffset());
        method = METHOD_DISCREET_UPDATE;
      }
      else
      {
        method = METHOD_FULL_UPDATE;
      }
      break;
    default:
      break;
    }

    XBMC->Log(LOG_DEBUG, "%s - %u : Dealing with the problem using method %i", __FUNCTION__, index, method);
    if (method == METHOD_DISCREET_UPDATE)
    {
      if (!m_control->UpdateRecordSchedule(*(handle.GetPtr())))
        return MSM_ERROR_FAILED;
      node->m_rule = handle; // sync node
      //if (!m_con.UpdateSchedules(handle.RecordID()))
      //  return MSM_ERROR_FAILED;
      return MSM_ERROR_SUCCESS;
    }
    if (method == METHOD_CREATE_OVERRIDE)
    {
      handle = MakeOverride(handle, recording);
      XBMC->Log(LOG_DEBUG, "%s - %u : Creating Override for %u (%s: %s) on %i (%s)"
                , __FUNCTION__, index, (unsigned)node->m_rule.RecordID(), node->m_rule.Title().c_str(),
                node->m_rule.Subtitle().c_str(), recording->ChannelID(), recording->Callsign().c_str());

      if (!m_control->AddRecordSchedule(*(handle.GetPtr())))
        return MSM_ERROR_FAILED;
      node->m_overrideRules.push_back(handle); // sync node
      //if (!m_con.UpdateSchedules(handle.RecordID()))
      //  return MSM_ERROR_FAILED;
      return MSM_ERROR_SUCCESS;
    }
    if (method == METHOD_FULL_UPDATE)
    {
      handle = newrule;
      handle.SetRecordID(node->m_rule.RecordID());
      if (!m_control->UpdateRecordSchedule(*(handle.GetPtr())))
        return MSM_ERROR_FAILED;
      node->m_rule = handle; // sync node
      //if (!m_con.UpdateSchedules(handle.RecordID()))
      //  return MSM_ERROR_FAILED;
      return MSM_ERROR_SUCCESS;
    }
  }

  return MSM_ERROR_NOT_IMPLEMENTED;
}

RecordingRuleNodePtr MythScheduleManager::FindRuleById(uint32_t recordid) const
{
  CLockObject lock(m_lock);

  NodeById::const_iterator it = m_rulesById.find(recordid);
  if (it != m_rulesById.end())
    return it->second;
  return RecordingRuleNodePtr();
}

ScheduleList MythScheduleManager::FindUpComingByRuleId(uint32_t recordid) const
{
  CLockObject lock(m_lock);

  ScheduleList found;
  std::pair<RecordingIndexByRuleId::const_iterator, RecordingIndexByRuleId::const_iterator> range = m_recordingIndexByRuleId.equal_range(recordid);
  if (range.first != m_recordingIndexByRuleId.end())
  {
    for (RecordingIndexByRuleId::const_iterator it = range.first; it != range.second; ++it)
    {
      RecordingList::const_iterator recordingIt = m_recordings.find(it->second);
      if (recordingIt != m_recordings.end())
        found.push_back(std::make_pair(it->second, recordingIt->second));
    }
  }
  return found;
}

ScheduledPtr MythScheduleManager::FindUpComingByIndex(uint32_t index) const
{
  CLockObject lock(m_lock);

  RecordingList::const_iterator it = m_recordings.find(index);
  if (it != m_recordings.end())
    return it->second;
  return ScheduledPtr();
}

bool MythScheduleManager::OpenControl()
{
  if (m_control)
    return m_control->Open();
  return false;
}

void MythScheduleManager::CloseControl()
{
  if (m_control)
    m_control->Close();
}

void MythScheduleManager::Update()
{
  CLockObject lock(m_lock);

  // Setup VersionHelper for the new set
  this->Setup();
  Myth::RecordScheduleListPtr records = m_control->GetRecordScheduleList();
  m_rules.clear();
  m_rulesById.clear();
  m_templates.clear();
  for (Myth::RecordScheduleList::iterator it = records->begin(); it != records->end(); ++it)
  {
    MythRecordingRule rule(*it);
    RecordingRuleNodePtr node = RecordingRuleNodePtr(new MythRecordingRuleNode(rule));
    m_rules.push_back(node);
    m_rulesById.insert(NodeById::value_type(rule.RecordID(), node));
    if (node->GetRule().Type() == Myth::RT_TemplateRecord)
      m_templates.push_back(node);
  }

  for (NodeList::iterator it = m_rules.begin(); it != m_rules.end(); ++it)
    // Is override rule ? Then find main rule and link to it
    if ((*it)->IsOverrideRule())
    {
      // First check parentid. Then fallback searching the same timeslot
      NodeById::iterator itp = m_rulesById.find((*it)->m_rule.ParentID());
      if (itp != m_rulesById.end())
      {
        itp->second->m_overrideRules.push_back((*it)->m_rule);
        (*it)->m_mainRule = itp->second->m_rule;
      }
      else
      {
        for (NodeList::iterator itm = m_rules.begin(); itm != m_rules.end(); ++itm)
          if (!(*itm)->IsOverrideRule() && m_versionHelper->SameTimeslot((*it)->m_rule, (*itm)->m_rule))
          {
            (*itm)->m_overrideRules.push_back((*it)->m_rule);
            (*it)->m_mainRule = (*itm)->m_rule;
          }

      }
    }

  m_recordings.clear();
  m_recordingIndexByRuleId.clear();
  // Add upcoming recordings
  Myth::ProgramListPtr recordings = m_control->GetUpcomingList();
  for (Myth::ProgramList::iterator it = recordings->begin(); it != recordings->end(); ++it)
  {
    ScheduledPtr scheduled = ScheduledPtr(new MythProgramInfo(*it));
    uint32_t index = MakeIndex(scheduled);
    m_recordings.insert(RecordingList::value_type(index, scheduled));
    m_recordingIndexByRuleId.insert(RecordingIndexByRuleId::value_type(scheduled->RecordID(), index));
  }

  // Add missed programs (NOT RECORDING) to upcoming recordings. User could delete them as needed.
  /*
  if (m_showNotRecording)
  {
    Myth::ProgramList norec = m_control->???;
    for (Myth::ProgramList::iterator it = norec.begin(); it != norec.end(); ++it)
    {
      if (m_recordingIndexByRuleId.count(it->second.RecordID()) == 0)
      {
        NodeById::const_iterator itr = m_rulesById.find(it->second.RecordID());
        if (itr != m_rulesById.end() && !itr->second->HasOverrideRules())
        {
          ScheduledPtr scheduled = ScheduledPtr(new MythProgramInfo(*it));
          uint32_t index = MakeIndex(scheduled);
          m_recordings.insert(RecordingList::value_type(index, scheduled));
          m_recordingIndexByRuleId.insert(RecordingIndexByRuleId::value_type(scheduled->RecordID(), index));
        }
      }
    }
  }
  */

  if (g_bExtraDebug)
  {
    for (NodeList::iterator it = m_rules.begin(); it != m_rules.end(); ++it)
      XBMC->Log(LOG_DEBUG, "%s - Rule node - recordid: %u, parentid: %u, type: %d, overriden: %s", __FUNCTION__,
              (unsigned)(*it)->m_rule.RecordID(), (unsigned)(*it)->m_rule.ParentID(),
              (int)(*it)->m_rule.Type(), ((*it)->HasOverrideRules() ? "Yes" : "No"));
    for (RecordingList::iterator it = m_recordings.begin(); it != m_recordings.end(); ++it)
      XBMC->Log(LOG_DEBUG, "%s - Recording - recordid: %u, index: %u, status: %d, title: %s", __FUNCTION__,
              (unsigned)it->second->RecordID(), (unsigned)it->first, it->second->Status(), it->second->Title().c_str());
  }
}

RuleMetadata MythScheduleManager::GetMetadata(const MythRecordingRule &rule) const
{
  return m_versionHelper->GetMetadata(rule);
}

MythRecordingRule MythScheduleManager::NewFromTemplate(MythEPGInfo &epgInfo)
{
  return m_versionHelper->NewFromTemplate(epgInfo);
}

MythRecordingRule MythScheduleManager::NewSingleRecord(MythEPGInfo &epgInfo)
{
  return m_versionHelper->NewSingleRecord(epgInfo);
}

MythRecordingRule MythScheduleManager::NewDailyRecord(MythEPGInfo &epgInfo)
{
  return m_versionHelper->NewDailyRecord(epgInfo);
}

MythRecordingRule MythScheduleManager::NewWeeklyRecord(MythEPGInfo &epgInfo)
{
  return m_versionHelper->NewWeeklyRecord(epgInfo);
}

MythRecordingRule MythScheduleManager::NewChannelRecord(MythEPGInfo &epgInfo)
{
  return m_versionHelper->NewChannelRecord(epgInfo);
}

MythRecordingRule MythScheduleManager::NewOneRecord(MythEPGInfo &epgInfo)
{
  return m_versionHelper->NewOneRecord(epgInfo);
}

TemplateRuleList MythScheduleManager::GetTemplateRules() const
{
  return m_templates;
}

bool MythScheduleManager::ToggleShowNotRecording()
{
  m_showNotRecording ^= true;
  return m_showNotRecording;
}

///////////////////////////////////////////////////////////////////////////////
////
//// Version Helper for unknown version (no helper)
////

bool MythScheduleHelperNoHelper::SameTimeslot(MythRecordingRule &first, MythRecordingRule &second) const
{
  (void)first;
  (void)second;
  return false;
}

RuleMetadata MythScheduleHelperNoHelper::GetMetadata(const MythRecordingRule &rule) const
{
  RuleMetadata meta;
  (void)rule;
  meta.isRepeating = false;
  meta.weekDays = 0;
  meta.marker = "";
  return meta;
}

MythRecordingRule MythScheduleHelperNoHelper::NewFromTemplate(MythEPGInfo &epgInfo)
{
  (void)epgInfo;
  return MythRecordingRule();
}

MythRecordingRule MythScheduleHelperNoHelper::NewSingleRecord(MythEPGInfo &epgInfo)
{
  (void)epgInfo;
  return MythRecordingRule();
}

MythRecordingRule MythScheduleHelperNoHelper::NewDailyRecord(MythEPGInfo &epgInfo)
{
  (void)epgInfo;
  return MythRecordingRule();
}

MythRecordingRule MythScheduleHelperNoHelper::NewWeeklyRecord(MythEPGInfo &epgInfo)
{
  (void)epgInfo;
  return MythRecordingRule();
}

MythRecordingRule MythScheduleHelperNoHelper::NewChannelRecord(MythEPGInfo &epgInfo)
{
  (void)epgInfo;
  return MythRecordingRule();
}

MythRecordingRule MythScheduleHelperNoHelper::NewOneRecord(MythEPGInfo &epgInfo)
{
  (void)epgInfo;
  return MythRecordingRule();
}

///////////////////////////////////////////////////////////////////////////////
////
//// Version helper for backend version 75 (0.26)
////

bool MythScheduleHelper75::SameTimeslot(MythRecordingRule &first, MythRecordingRule &second) const
{
  time_t first_st = first.StartTime();
  time_t second_st = second.StartTime();

  switch (first.Type())
  {
  case Myth::RT_NotRecording:
  case Myth::RT_SingleRecord:
  case Myth::RT_OverrideRecord:
  case Myth::RT_DontRecord:
    return
    second_st == first_st &&
            second.EndTime() == first.EndTime() &&
            second.ChannelID() == first.ChannelID() &&
            second.Filter() == first.Filter();

  case Myth::RT_OneRecord: // FindOneRecord
    return
    second.Title() == first.Title() &&
            second.ChannelID() == first.ChannelID() &&
            second.Filter() == first.Filter();

  case Myth::RT_DailyRecord: // TimeslotRecord
    return
    second.Title() == first.Title() &&
            daytime(&first_st) == daytime(&second_st) &&
            second.ChannelID() == first.ChannelID() &&
            second.Filter() == first.Filter();

  case Myth::RT_WeeklyRecord: // WeekslotRecord
    return
    second.Title() == first.Title() &&
            daytime(&first_st) == daytime(&second_st) &&
            weekday(&first_st) == weekday(&second_st) &&
            second.ChannelID() == first.ChannelID() &&
            second.Filter() == first.Filter();

  case Myth::RT_FindDailyRecord:
    return
    second.Title() == first.Title() &&
            second.ChannelID() == first.ChannelID() &&
            second.Filter() == first.Filter();

  case Myth::RT_FindWeeklyRecord:
    return
    second.Title() == first.Title() &&
            weekday(&first_st) == weekday(&second_st) &&
            second.ChannelID() == first.ChannelID() &&
            second.Filter() == first.Filter();

  case Myth::RT_ChannelRecord:
    return
    second.Title() == first.Title() &&
            second.ChannelID() == first.ChannelID() &&
            second.Filter() == first.Filter();

  case Myth::RT_AllRecord:
    return
    second.Title() == first.Title() &&
            second.Filter() == first.Filter();

  default:
    break;
  }
  return false;
}

RuleMetadata MythScheduleHelper75::GetMetadata(const MythRecordingRule &rule) const
{
  RuleMetadata meta;
  time_t st = rule.StartTime();
  meta.isRepeating = false;
  meta.weekDays = 0;
  meta.marker = "";
  switch (rule.Type())
  {
    case Myth::RT_DailyRecord:
    case Myth::RT_FindDailyRecord:
      meta.isRepeating = true;
      meta.weekDays = 0x7F;
      meta.marker = "d";
      break;
    case Myth::RT_WeeklyRecord:
    case Myth::RT_FindWeeklyRecord:
      meta.isRepeating = true;
      meta.weekDays = 1 << ((weekday(&st) + 6) % 7);
      meta.marker = "w";
      break;
    case Myth::RT_ChannelRecord:
      meta.isRepeating = true;
      meta.weekDays = 0x7F;
      meta.marker = "C";
      break;
    case Myth::RT_AllRecord:
      meta.isRepeating = true;
      meta.weekDays = 0x7F;
      meta.marker = "A";
      break;
    case Myth::RT_OneRecord:
      meta.isRepeating = false;
      meta.weekDays = 0;
      meta.marker = "1";
      break;
    case Myth::RT_DontRecord:
      meta.isRepeating = false;
      meta.weekDays = 0;
      meta.marker = "x";
      break;
    case Myth::RT_OverrideRecord:
      meta.isRepeating = false;
      meta.weekDays = 0;
      meta.marker = "o";
      break;
    default:
      break;
  }
  return meta;
}

MythRecordingRule MythScheduleHelper75::NewFromTemplate(MythEPGInfo &epgInfo)
{
  MythRecordingRule rule;
  // Load rule template from selected provider
  switch (g_iRecTemplateType)
  {
  case 1: // Template provider is 'MythTV', then load the template from backend.
    if (!epgInfo.IsNull())
    {
      TemplateRuleList templates = m_manager->GetTemplateRules();
      TemplateRuleList::const_iterator tplIt = templates.end();
      for (TemplateRuleList::const_iterator it = templates.begin(); it != templates.end(); ++it)
      {
        if ((*it)->GetRule().Category() == epgInfo.Category())
        {
          tplIt = it;
          break;
        }
        if ((*it)->GetRule().Category() == epgInfo.CategoryType())
        {
          tplIt = it;
          continue;
        }
        if ((*it)->GetRule().Category() == "Default" && tplIt == templates.end())
          tplIt = it;
      }
      if (tplIt != templates.end())
      {
        XBMC->Log(LOG_INFO, "Overriding the rule with template %u '%s'", (unsigned)(*tplIt)->GetRule().RecordID(), (*tplIt)->GetRule().Title().c_str());
        rule.SetPriority((*tplIt)->GetRule().Priority());
        rule.SetStartOffset((*tplIt)->GetRule().StartOffset());
        rule.SetEndOffset((*tplIt)->GetRule().EndOffset());
        rule.SetSearchType((*tplIt)->GetRule().SearchType());
        rule.SetDuplicateControlMethod((*tplIt)->GetRule().DuplicateControlMethod());
        rule.SetCheckDuplicatesInType((*tplIt)->GetRule().CheckDuplicatesInType());
        rule.SetRecordingGroup((*tplIt)->GetRule().RecordingGroup());
        rule.SetRecordingProfile((*tplIt)->GetRule().RecordingProfile());
        rule.SetStorageGroup((*tplIt)->GetRule().StorageGroup());
        rule.SetPlaybackGroup((*tplIt)->GetRule().PlaybackGroup());
        rule.SetUserJob(1, (*tplIt)->GetRule().UserJob(1));
        rule.SetUserJob(2, (*tplIt)->GetRule().UserJob(2));
        rule.SetUserJob(3, (*tplIt)->GetRule().UserJob(3));
        rule.SetUserJob(4, (*tplIt)->GetRule().UserJob(4));
        rule.SetAutoTranscode((*tplIt)->GetRule().AutoTranscode());
        rule.SetAutoCommFlag((*tplIt)->GetRule().AutoCommFlag());
        rule.SetAutoExpire((*tplIt)->GetRule().AutoExpire());
        rule.SetAutoMetadata((*tplIt)->GetRule().AutoMetadata());
        rule.SetMaxEpisodes((*tplIt)->GetRule().MaxEpisodes());
        rule.SetNewExpiresOldRecord((*tplIt)->GetRule().NewExpiresOldRecord());
        rule.SetFilter((*tplIt)->GetRule().Filter());
      }
      else
        XBMC->Log(LOG_INFO, "No template found for the category '%s'", epgInfo.Category().c_str());
    }
    break;
  case 0: // Template provider is 'Internal', then set rule with settings
    rule.SetAutoCommFlag(g_bRecAutoCommFlag);
    rule.SetAutoMetadata(g_bRecAutoMetadata);
    rule.SetAutoTranscode(g_bRecAutoTranscode);
    rule.SetUserJob(1, g_bRecAutoRunJob1);
    rule.SetUserJob(2, g_bRecAutoRunJob2);
    rule.SetUserJob(3, g_bRecAutoRunJob3);
    rule.SetUserJob(4, g_bRecAutoRunJob4);
    rule.SetAutoExpire(g_bRecAutoExpire);
    rule.SetTranscoder(g_iRecTranscoder);
  }

  // Category override
  if (!epgInfo.IsNull())
  {
    Myth::SettingPtr overTimeCategory = m_control->GetSetting("OverTimeCategory", false);
    if (overTimeCategory && (overTimeCategory->value == epgInfo.Category() || overTimeCategory->value == epgInfo.CategoryType()))
    {
      Myth::SettingPtr categoryOverTime = m_control->GetSetting("CategoryOverTime", false);
      if (categoryOverTime && !categoryOverTime->value.empty())
      {
        int offset = atoi(categoryOverTime->value.c_str());
        XBMC->Log(LOG_DEBUG, "Overriding end offset for category %s: +%d", overTimeCategory->value.c_str(), offset);
        rule.SetEndOffset(offset);
      }
    }
  }
  return rule;
}

MythRecordingRule MythScheduleHelper75::NewSingleRecord(MythEPGInfo &epgInfo)
{
  MythRecordingRule rule = this->NewFromTemplate(epgInfo);

  rule.SetType(Myth::RT_SingleRecord);

  if (!epgInfo.IsNull())
  {
    rule.SetChannelID(epgInfo.ChannelID());
    rule.SetStartTime(epgInfo.StartTime());
    rule.SetEndTime(epgInfo.EndTime());
    rule.SetSearchType(Myth::ST_NoSearch);
    rule.SetTitle(epgInfo.Title());
    rule.SetSubtitle(epgInfo.Subtitle());
    rule.SetCategory(epgInfo.Category());
    rule.SetDescription(epgInfo.Description());
    rule.SetCallsign(epgInfo.Callsign());
    rule.SetProgramID(epgInfo.ProgramID());
    rule.SetSeriesID(epgInfo.SeriesID());
  }
  else
  {
    // kManualSearch = http://www.gossamer-threads.com/lists/mythtv/dev/155150?search_string=kManualSearch;#155150
    rule.SetSearchType(Myth::ST_ManualSearch);
  }
  rule.SetDuplicateControlMethod(Myth::DM_CheckNone);
  rule.SetCheckDuplicatesInType(Myth::DI_InAll);
  rule.SetInactive(false);
  return rule;
}

MythRecordingRule MythScheduleHelper75::NewDailyRecord(MythEPGInfo &epgInfo)
{
  MythRecordingRule rule = this->NewFromTemplate(epgInfo);

  rule.SetType(Myth::RT_DailyRecord);

  if (!epgInfo.IsNull())
  {
    rule.SetSearchType(Myth::ST_NoSearch);
    rule.SetChannelID(epgInfo.ChannelID());
    rule.SetStartTime(epgInfo.StartTime());
    rule.SetEndTime(epgInfo.EndTime());
    rule.SetTitle(epgInfo.Title());
    rule.SetSubtitle(epgInfo.Subtitle());
    rule.SetCategory(epgInfo.Category());
    rule.SetDescription(epgInfo.Description());
    rule.SetCallsign(epgInfo.Callsign());
    rule.SetProgramID(epgInfo.ProgramID());
    rule.SetSeriesID(epgInfo.SeriesID());
  }
  else
  {
    // kManualSearch = http://www.gossamer-threads.com/lists/mythtv/dev/155150?search_string=kManualSearch;#155150
    rule.SetSearchType(Myth::ST_ManualSearch);
  }
  rule.SetDuplicateControlMethod(Myth::DM_CheckSubtitleAndDescription);
  rule.SetCheckDuplicatesInType(Myth::DI_InAll);
  rule.SetInactive(false);
  return rule;
}

MythRecordingRule MythScheduleHelper75::NewWeeklyRecord(MythEPGInfo &epgInfo)
{
  MythRecordingRule rule = this->NewFromTemplate(epgInfo);

  rule.SetType(Myth::RT_WeeklyRecord);

  if (!epgInfo.IsNull())
  {
    rule.SetSearchType(Myth::ST_NoSearch);
    rule.SetChannelID(epgInfo.ChannelID());
    rule.SetStartTime(epgInfo.StartTime());
    rule.SetEndTime(epgInfo.EndTime());
    rule.SetTitle(epgInfo.Title());
    rule.SetSubtitle(epgInfo.Subtitle());
    rule.SetCategory(epgInfo.Category());
    rule.SetDescription(epgInfo.Description());
    rule.SetCallsign(epgInfo.Callsign());
    rule.SetProgramID(epgInfo.ProgramID());
    rule.SetSeriesID(epgInfo.SeriesID());
  }
  else
  {
    // kManualSearch = http://www.gossamer-threads.com/lists/mythtv/dev/155150?search_string=kManualSearch;#155150
    rule.SetSearchType(Myth::ST_ManualSearch);
  }
  rule.SetDuplicateControlMethod(Myth::DM_CheckSubtitleAndDescription);
  rule.SetCheckDuplicatesInType(Myth::DI_InAll);
  rule.SetInactive(false);
  return rule;
}

MythRecordingRule MythScheduleHelper75::NewChannelRecord(MythEPGInfo &epgInfo)
{
  MythRecordingRule rule = this->NewFromTemplate(epgInfo);

  rule.SetType(Myth::RT_ChannelRecord);

  if (!epgInfo.IsNull())
  {
    rule.SetSearchType(Myth::ST_TitleSearch);
    rule.SetChannelID(epgInfo.ChannelID());
    rule.SetStartTime(epgInfo.StartTime());
    rule.SetEndTime(epgInfo.EndTime());
    rule.SetTitle(epgInfo.Title());
    // Backend use the description to find program by keywords or title
    rule.SetSubtitle("");
    rule.SetDescription(epgInfo.Title());
    rule.SetCategory(epgInfo.Category());
    rule.SetCallsign(epgInfo.Callsign());
    rule.SetProgramID(epgInfo.ProgramID());
    rule.SetSeriesID(epgInfo.SeriesID());
  }
  else
  {
    // Not feasible
    rule.SetType(Myth::RT_NotRecording);
  }
  rule.SetDuplicateControlMethod(Myth::DM_CheckSubtitleAndDescription);
  rule.SetCheckDuplicatesInType(Myth::DI_InAll);
  rule.SetInactive(false);
  return rule;
}

MythRecordingRule MythScheduleHelper75::NewOneRecord(MythEPGInfo &epgInfo)
{
  MythRecordingRule rule = this->NewFromTemplate(epgInfo);

  rule.SetType(Myth::RT_OneRecord);

  if (!epgInfo.IsNull())
  {
    rule.SetSearchType(Myth::ST_TitleSearch);
    rule.SetChannelID(epgInfo.ChannelID());
    rule.SetStartTime(epgInfo.StartTime());
    rule.SetEndTime(epgInfo.EndTime());
    rule.SetTitle(epgInfo.Title());
    // Backend use the description to find program by keywords or title
    rule.SetSubtitle("");
    rule.SetDescription(epgInfo.Title());
    rule.SetCategory(epgInfo.Category());
    rule.SetCallsign(epgInfo.Callsign());
    rule.SetProgramID(epgInfo.ProgramID());
    rule.SetSeriesID(epgInfo.SeriesID());
  }
  else
  {
    // Not feasible
    rule.SetType(Myth::RT_NotRecording);
  }
  rule.SetDuplicateControlMethod(Myth::DM_CheckSubtitleAndDescription);
  rule.SetCheckDuplicatesInType(Myth::DI_InAll);
  rule.SetInactive(false);
  return rule;
}

///////////////////////////////////////////////////////////////////////////////
////
//// Version helper for database up to 1309 (0.27)
////
//// Remove the Timeslot and Weekslot recording rule types. These rule
//// types are too rigid and don't work when a broadcaster shifts the
//// starting time of a program by a few minutes. Users should now use
//// Channel recording rules in place of Timeslot and Weekslot rules. To
//// approximate the old functionality, two new schedule filters have been
//// added. In addition, the new "This time" and "This day and time"
//// filters are less strict and match any program starting within 10
//// minutes of the recording rule time.
//// Restrict the use of the FindDaily? and FindWeekly? recording rule types
//// (now simply called Daily and Weekly) to search and manual recording
//// rules. These rule types are rarely needed and limiting their use to
//// the most powerful cases simplifies the user interface for the more
//// common cases. Users should now use Daily and Weekly, custom search
//// rules in place of FindDaily? and FindWeekly? rules.
//// Any existing recording rules using the no longer supported or allowed
//// types are automatically converted to the suggested alternatives.
////

RuleMetadata MythScheduleHelper76::GetMetadata(const MythRecordingRule &rule) const
{
  RuleMetadata meta;
  time_t st = rule.StartTime();
  meta.isRepeating = false;
  meta.weekDays = 0;
  meta.marker = "";
  switch (rule.Type())
  {
    case Myth::RT_DailyRecord:
    case Myth::RT_FindDailyRecord:
      meta.isRepeating = true;
      meta.weekDays = 0x7F;
      meta.marker = "d";
      break;
    case Myth::RT_WeeklyRecord:
    case Myth::RT_FindWeeklyRecord:
      meta.isRepeating = true;
      meta.weekDays = 1 << ((weekday(&st) + 6) % 7);
      meta.marker = "w";
      break;
    case Myth::RT_ChannelRecord:
      meta.isRepeating = true;
      meta.weekDays = 0x7F;
      meta.marker = "C";
      break;
    case Myth::RT_AllRecord:
      meta.isRepeating = true;
      if ((rule.Filter() & Myth::FM_ThisDayAndTime))
      {
        meta.weekDays = 1 << ((weekday(&st) + 6) % 7);
        meta.marker = "w";
      }
      else if ((rule.Filter() & Myth::FM_ThisTime))
      {
        meta.weekDays = 0x7F;
        meta.marker = "d";
      }
      else
      {
        meta.weekDays = 0x7F;
        meta.marker = "A";
      }
      break;
    case Myth::RT_OneRecord:
      meta.isRepeating = false;
      meta.weekDays = 0;
      meta.marker = "1";
      break;
    case Myth::RT_DontRecord:
      meta.isRepeating = false;
      meta.weekDays = 0;
      meta.marker = "x";
      break;
    case Myth::RT_OverrideRecord:
      meta.isRepeating = false;
      meta.weekDays = 0;
      meta.marker = "o";
      break;
    default:
      break;
  }
  return meta;
}

MythRecordingRule MythScheduleHelper76::NewDailyRecord(MythEPGInfo &epgInfo)
{
  unsigned int filter;
  MythRecordingRule rule = this->NewFromTemplate(epgInfo);

  rule.SetType(Myth::RT_AllRecord);
  filter = Myth::FM_ThisChannel + Myth::FM_ThisTime;
  rule.SetFilter(filter);

  if (!epgInfo.IsNull())
  {
    rule.SetSearchType(Myth::ST_NoSearch);
    rule.SetChannelID(epgInfo.ChannelID());
    rule.SetStartTime(epgInfo.StartTime());
    rule.SetEndTime(epgInfo.EndTime());
    rule.SetTitle(epgInfo.Title());
    rule.SetSubtitle(epgInfo.Subtitle());
    rule.SetCategory(epgInfo.Category());
    rule.SetDescription(epgInfo.Description());
    rule.SetCallsign(epgInfo.Callsign());
    rule.SetProgramID(epgInfo.ProgramID());
    rule.SetSeriesID(epgInfo.SeriesID());
  }
  else
  {
    // No EPG! Create custom daily for this channel
    rule.SetType(Myth::RT_DailyRecord);
    rule.SetFilter(Myth::FM_ThisChannel);
    // kManualSearch = http://www.gossamer-threads.com/lists/mythtv/dev/155150?search_string=kManualSearch;#155150
    rule.SetSearchType(Myth::ST_ManualSearch);
  }
  rule.SetDuplicateControlMethod(Myth::DM_CheckSubtitleAndDescription);
  rule.SetCheckDuplicatesInType(Myth::DI_InAll);
  rule.SetInactive(false);
  return rule;
}

MythRecordingRule MythScheduleHelper76::NewWeeklyRecord(MythEPGInfo &epgInfo)
{
  unsigned int filter;
  MythRecordingRule rule = this->NewFromTemplate(epgInfo);

  rule.SetType(Myth::RT_AllRecord);
  filter = Myth::FM_ThisChannel + Myth::FM_ThisDayAndTime;
  rule.SetFilter(filter);

  if (!epgInfo.IsNull())
  {
    rule.SetSearchType(Myth::ST_NoSearch);
    rule.SetChannelID(epgInfo.ChannelID());
    rule.SetStartTime(epgInfo.StartTime());
    rule.SetEndTime(epgInfo.EndTime());
    rule.SetTitle(epgInfo.Title());
    rule.SetSubtitle(epgInfo.Subtitle());
    rule.SetCategory(epgInfo.Category());
    rule.SetDescription(epgInfo.Description());
    rule.SetCallsign(epgInfo.Callsign());
    rule.SetProgramID(epgInfo.ProgramID());
    rule.SetSeriesID(epgInfo.SeriesID());
  }
  else
  {
    // No EPG! Create custom weekly for this channel
    rule.SetType(Myth::RT_WeeklyRecord);
    rule.SetFilter(Myth::FM_ThisChannel);
    // kManualSearch = http://www.gossamer-threads.com/lists/mythtv/dev/155150?search_string=kManualSearch;#155150
    rule.SetSearchType(Myth::ST_ManualSearch);
  }
  rule.SetDuplicateControlMethod(Myth::DM_CheckSubtitleAndDescription);
  rule.SetCheckDuplicatesInType(Myth::DI_InAll);
  rule.SetInactive(false);
  return rule;
}

MythRecordingRule MythScheduleHelper76::NewChannelRecord(MythEPGInfo &epgInfo)
{
  unsigned int filter;
  MythRecordingRule rule = this->NewFromTemplate(epgInfo);

  rule.SetType(Myth::RT_AllRecord);
  filter = Myth::FM_ThisChannel;
  rule.SetFilter(filter);

  if (!epgInfo.IsNull())
  {
    rule.SetSearchType(Myth::ST_NoSearch);
    rule.SetChannelID(epgInfo.ChannelID());
    rule.SetStartTime(epgInfo.StartTime());
    rule.SetEndTime(epgInfo.EndTime());
    rule.SetTitle(epgInfo.Title());
    rule.SetSubtitle(epgInfo.Subtitle());
    rule.SetCategory(epgInfo.Category());
    rule.SetDescription(epgInfo.Description());
    rule.SetCallsign(epgInfo.Callsign());
    rule.SetProgramID(epgInfo.ProgramID());
    rule.SetSeriesID(epgInfo.SeriesID());
  }
  else
  {
    // Not feasible
    rule.SetType(Myth::RT_NotRecording);
  }
  rule.SetDuplicateControlMethod(Myth::DM_CheckSubtitleAndDescription);
  rule.SetCheckDuplicatesInType(Myth::DI_InAll);
  rule.SetInactive(false);
  return rule;
}

MythRecordingRule MythScheduleHelper76::NewOneRecord(MythEPGInfo &epgInfo)
{
  unsigned int filter;
  MythRecordingRule rule = this->NewFromTemplate(epgInfo);

  rule.SetType(Myth::RT_OneRecord);
  filter = Myth::FM_ThisEpisode;
  rule.SetFilter(filter);

  if (!epgInfo.IsNull())
  {
    rule.SetSearchType(Myth::ST_NoSearch);
    rule.SetChannelID(epgInfo.ChannelID());
    rule.SetStartTime(epgInfo.StartTime());
    rule.SetEndTime(epgInfo.EndTime());
    rule.SetTitle(epgInfo.Title());
    rule.SetSubtitle(epgInfo.Subtitle());
    rule.SetCategory(epgInfo.Category());
    rule.SetDescription(epgInfo.Description());
    rule.SetCallsign(epgInfo.Callsign());
    rule.SetProgramID(epgInfo.ProgramID());
    rule.SetSeriesID(epgInfo.SeriesID());
  }
  else
  {
    // Not feasible
    rule.SetType(Myth::RT_NotRecording);
  }
  rule.SetDuplicateControlMethod(Myth::DM_CheckSubtitleAndDescription);
  rule.SetCheckDuplicatesInType(Myth::DI_InAll);
  rule.SetInactive(false);
  return rule;
}
