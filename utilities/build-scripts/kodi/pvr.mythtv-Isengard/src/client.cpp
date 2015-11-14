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

#include "client.h"
#include "pvrclient-mythtv.h"
#include "guidialogyesno.h"

#include <kodi/xbmc_pvr_dll.h>

using namespace ADDON;

/* User adjustable settings are saved here.
 * Default values are defined inside client.h
 * and exported to the other source files.
 */
bool          g_bNotifyAddonFailure     = true;                             ///< Notify user after failure of create function
std::string   g_szMythHostname          = DEFAULT_HOST;                     ///< The Host name or IP of the mythtv server
std::string   g_szMythHostEther         = "";                               ///< The Host MAC address of the mythtv server
int           g_iProtoPort              = DEFAULT_PROTO_PORT;               ///< The mythtv protocol port (default is 6543)
int           g_iWSApiPort              = DEFAULT_WSAPI_PORT;               ///< The mythtv sevice API port (default is 6544)
std::string   g_szWSSecurityPin         = DEFAULT_WSAPI_SECURITY_PIN;       ///< The default security pin for the mythtv wsapi
bool          g_bExtraDebug             = DEFAULT_EXTRA_DEBUG;              ///< Output extensive debug information to the log
bool          g_bLiveTV                 = DEFAULT_LIVETV;                   ///< LiveTV support (or recordings only)
bool          g_bLiveTVPriority         = DEFAULT_LIVETV_PRIORITY;          ///< MythTV Backend setting to allow live TV to move scheduled shows
int           g_iLiveTVConflictStrategy = DEFAULT_LIVETV_CONFLICT_STRATEGY; ///< Conflict resolving strategy (0=
bool          g_bChannelIcons           = DEFAULT_CHANNEL_ICONS;            ///< Load Channel Icons
bool          g_bRecordingIcons         = DEFAULT_RECORDING_ICONS;          ///< Load Recording Icons (Fanart/Thumbnails)
int           g_iRecTemplateType        = DEFAULT_RECORD_TEMPLATE;          ///< Template type for new record (0=Internal, 1=MythTV)
bool          g_bRecAutoMetadata        = true;
bool          g_bRecAutoCommFlag        = false;
bool          g_bRecAutoTranscode       = false;
bool          g_bRecAutoRunJob1         = false;
bool          g_bRecAutoRunJob2         = false;
bool          g_bRecAutoRunJob3         = false;
bool          g_bRecAutoRunJob4         = false;
bool          g_bRecAutoExpire          = false;
int           g_iRecTranscoder          = 0;
bool          g_bDemuxing               = DEFAULT_HANDLE_DEMUXING;
int           g_iTuneDelay              = DEFAULT_TUNE_DELAY;
int           g_iGroupRecordings        = GROUP_RECORDINGS_ALWAYS;
int           g_iEnableEDL              = ENABLE_EDL_ALWAYS;
bool          g_bBlockMythShutdown      = DEFAULT_BLOCK_SHUTDOWN;
bool          g_bLimitTuneAttempts      = DEFAULT_LIMIT_TUNE_ATTEMPTS;

///* Client member variables */
ADDON_STATUS  m_CurStatus               = ADDON_STATUS_UNKNOWN;
bool          g_bCreated                = false;
int           g_iClientID               = -1;
std::string   g_szUserPath              = "";
std::string   g_szClientPath            = "";

PVRClientMythTV         *g_client       = NULL;

CHelper_libXBMC_addon   *XBMC           = NULL;
CHelper_libXBMC_pvr     *PVR            = NULL;
CHelper_libKODI_guilib  *GUI            = NULL;
CHelper_libXBMC_codec   *CODEC          = NULL;

extern "C" {

/***********************************************************
 * Standard AddOn related public library functions
 ***********************************************************/

ADDON_STATUS ADDON_Create(void *hdl, void *props)
{
  if (!hdl)
    return ADDON_STATUS_PERMANENT_FAILURE;

  // Register handles
  XBMC = new CHelper_libXBMC_addon;

  if (!XBMC->RegisterMe(hdl))
  {
    SAFE_DELETE(XBMC);
    return ADDON_STATUS_PERMANENT_FAILURE;
  }
  XBMC->Log(LOG_DEBUG, "Creating MythTV PVR-Client");
  XBMC->Log(LOG_DEBUG, "Addon compiled with XBMC_PVR_API_VERSION: %s and XBMC_PVR_MIN_API_VERSION: %s", GetPVRAPIVersion(), GetMininumPVRAPIVersion());
  XBMC->Log(LOG_DEBUG, "Register handle @ libXBMC_addon...done");
  XBMC->Log(LOG_DEBUG, "Checking props...");
  if (!props)
  {
    SAFE_DELETE(XBMC);
    return ADDON_STATUS_PERMANENT_FAILURE;
  }
  XBMC->Log(LOG_DEBUG, "Checking props...done");
  PVR_PROPERTIES* pvrprops = (PVR_PROPERTIES*)props;

  XBMC->Log(LOG_DEBUG, "Register handle @ libXBMC_pvr...");
  PVR = new CHelper_libXBMC_pvr;
  if (!PVR->RegisterMe(hdl))
  {
    SAFE_DELETE(PVR);
    SAFE_DELETE(XBMC);
    return ADDON_STATUS_PERMANENT_FAILURE;
  }
  XBMC->Log(LOG_DEBUG, "Register handle @ libXBMC_pvr...done");

  XBMC->Log(LOG_DEBUG, "Register handle @ libXBMC_gui...");
  GUI = new CHelper_libKODI_guilib;
  if (!GUI->RegisterMe(hdl))
  {
    SAFE_DELETE(PVR);
    SAFE_DELETE(XBMC);
    SAFE_DELETE(GUI);
    return ADDON_STATUS_PERMANENT_FAILURE;
  }
  XBMC->Log(LOG_DEBUG, "Register handle @ libXBMC_gui...done");

  XBMC->Log(LOG_DEBUG, "Register handle @ libXBMC_codec...");
  CODEC = new CHelper_libXBMC_codec;
  if (!CODEC->RegisterMe(hdl))
  {
    SAFE_DELETE(CODEC);
    SAFE_DELETE(PVR);
    SAFE_DELETE(XBMC);
    SAFE_DELETE(GUI);
    return ADDON_STATUS_PERMANENT_FAILURE;
  }
  XBMC->Log(LOG_DEBUG, "Register handle @ libXBMC_codec...done");

  m_CurStatus    = ADDON_STATUS_UNKNOWN;
  g_szUserPath   = pvrprops->strUserPath;
  g_szClientPath = pvrprops->strClientPath;

  // Read settings
  XBMC->Log(LOG_DEBUG, "Loading settings...");
  char *buffer;
  buffer = (char*)malloc(1024);
  buffer[0] = 0; /* Set the end of string */

  /* Read setting "host" from settings.xml */
  if (XBMC->GetSetting("host", buffer))
    g_szMythHostname = buffer;
  else
  {
    /* If setting is unknown fallback to defaults */
    XBMC->Log(LOG_ERROR, "Couldn't get 'host' setting, falling back to '%s' as default", DEFAULT_HOST);
    g_szMythHostname = DEFAULT_HOST;
  }
  buffer[0] = 0;

  /* Read setting "port" from settings.xml */
  if (!XBMC->GetSetting("port", &g_iProtoPort))
  {
    /* If setting is unknown fallback to defaults */
    XBMC->Log(LOG_ERROR, "Couldn't get 'port' setting, falling back to '%d' as default", DEFAULT_PROTO_PORT);
    g_iProtoPort = DEFAULT_PROTO_PORT;
  }

  /* Read setting "wsport" from settings.xml */
  if (!XBMC->GetSetting("wsport", &g_iWSApiPort))
  {
    /* If setting is unknown fallback to defaults */
    XBMC->Log(LOG_ERROR, "Couldn't get 'wsport' setting, falling back to '%d' as default", DEFAULT_WSAPI_PORT);
    g_iWSApiPort = DEFAULT_WSAPI_PORT;
  }

  /* Read setting "wssecuritypin" from settings.xml */
  if (XBMC->GetSetting("wssecuritypin", buffer))
    g_szWSSecurityPin = buffer;
  else
  {
    /* If setting is unknown fallback to defaults */
    XBMC->Log(LOG_ERROR, "Couldn't get 'wssecuritypin' setting, falling back to '%s' as default", DEFAULT_WSAPI_SECURITY_PIN);
    g_szWSSecurityPin = DEFAULT_WSAPI_SECURITY_PIN;
  }
  buffer[0] = 0;

  /* Read setting "extradebug" from settings.xml */
  if (!XBMC->GetSetting("extradebug", &g_bExtraDebug))
  {
    /* If setting is unknown fallback to defaults */
    XBMC->Log(LOG_ERROR, "Couldn't get 'extradebug' setting, falling back to '%b' as default", DEFAULT_EXTRA_DEBUG);
    g_bExtraDebug = DEFAULT_EXTRA_DEBUG;
  }

  /* Read setting "LiveTV" from settings.xml */
  if (!XBMC->GetSetting("livetv", &g_bLiveTV))
  {
    /* If setting is unknown fallback to defaults */
    XBMC->Log(LOG_ERROR, "Couldn't get 'livetv' setting, falling back to '%b' as default", DEFAULT_LIVETV);
    g_bLiveTV = DEFAULT_LIVETV;
  }

  /* Read settings "Record livetv_conflict_method" from settings.xml */
  if (!XBMC->GetSetting("livetv_conflict_strategy", &g_iLiveTVConflictStrategy))
  {
    /* If setting is unknown fallback to defaults */
    XBMC->Log(LOG_ERROR, "Couldn't get 'livetv_conflict_method' setting, falling back to '%i' as default", DEFAULT_RECORD_TEMPLATE);
    g_iLiveTVConflictStrategy = DEFAULT_LIVETV_CONFLICT_STRATEGY;
  }

  /* Read settings "Record template" from settings.xml */
  if (!XBMC->GetSetting("rec_template_provider", &g_iRecTemplateType))
  {
    /* If setting is unknown fallback to defaults */
    XBMC->Log(LOG_ERROR, "Couldn't get 'rec_template_provider' setting, falling back to '%i' as default", DEFAULT_RECORD_TEMPLATE);
    g_iRecTemplateType = DEFAULT_RECORD_TEMPLATE;
  }
  /* Get internal template settings */
  if (!XBMC->GetSetting("rec_autometadata", &g_bRecAutoMetadata))
    g_bRecAutoMetadata = true;
  if (!XBMC->GetSetting("rec_autocommflag", &g_bRecAutoCommFlag))
    g_bRecAutoCommFlag = false;
  if (!XBMC->GetSetting("rec_autotranscode", &g_bRecAutoTranscode))
    g_bRecAutoTranscode = false;
  if (!XBMC->GetSetting("rec_autorunjob1", &g_bRecAutoRunJob1))
    g_bRecAutoRunJob1 = false;
  if (!XBMC->GetSetting("rec_autorunjob2", &g_bRecAutoRunJob2))
    g_bRecAutoRunJob2 = false;
  if (!XBMC->GetSetting("rec_autorunjob3", &g_bRecAutoRunJob3))
    g_bRecAutoRunJob3 = false;
  if (!XBMC->GetSetting("rec_autorunjob4", &g_bRecAutoRunJob4))
    g_bRecAutoRunJob4 = false;
  if (!XBMC->GetSetting("rec_autoexpire", &g_bRecAutoExpire))
    g_bRecAutoExpire = false;
  if (!XBMC->GetSetting("rec_transcoder", &g_iRecTranscoder))
    g_iRecTranscoder = 0;

  /* Read setting "demuxing" from settings.xml */
  if (!XBMC->GetSetting("demuxing", &g_bDemuxing))
  {
    /* If setting is unknown fallback to defaults */
    XBMC->Log(LOG_ERROR, "Couldn't get 'demuxing' setting, falling back to '%b' as default", DEFAULT_HANDLE_DEMUXING);
    g_bDemuxing = DEFAULT_HANDLE_DEMUXING;
  }

  /* Read setting "tunedelay" from settings.xml */
  if (!XBMC->GetSetting("tunedelay", &g_iTuneDelay))
  {
    /* If setting is unknown fallback to defaults */
    XBMC->Log(LOG_ERROR, "Couldn't get 'tunedelay' setting, falling back to '%d' as default", DEFAULT_TUNE_DELAY);
    g_iTuneDelay = DEFAULT_TUNE_DELAY;
  }

  /* Read setting "host_ether" from settings.xml */
  if (XBMC->GetSetting("host_ether", buffer))
    g_szMythHostEther = buffer;
  else
  {
    /* If setting is unknown fallback to defaults */
    g_szMythHostEther = "";
  }
  buffer[0] = 0;

  /* Read settings "group_recordings" from settings.xml */
  if (!XBMC->GetSetting("group_recordings", &g_iGroupRecordings))
  {
    /* If setting is unknown fallback to defaults */
    XBMC->Log(LOG_ERROR, "Couldn't get 'group_recordings' setting, falling back to '%i' as default", GROUP_RECORDINGS_ALWAYS);
    g_iGroupRecordings = GROUP_RECORDINGS_ALWAYS;
  }

  /* Read setting "enable_edl" from settings.xml */
  if (!XBMC->GetSetting("enable_edl", &g_iEnableEDL))
  {
    /* If setting is unknown fallback to defaults */
    XBMC->Log(LOG_ERROR, "Couldn't get 'enable_edl' setting, falling back to '%i' as default", ENABLE_EDL_ALWAYS);
    g_iEnableEDL = ENABLE_EDL_ALWAYS;
  }

  /* Read setting "block_shutdown" from settings.xml */
  if (!XBMC->GetSetting("block_shutdown", &g_bBlockMythShutdown))
  {
    /* If setting is unknown fallback to defaults */
    XBMC->Log(LOG_ERROR, "Couldn't get 'block_shutdown' setting, falling back to '%b' as default", DEFAULT_BLOCK_SHUTDOWN);
    g_bBlockMythShutdown = DEFAULT_BLOCK_SHUTDOWN;
  }

  /* Read setting "channel_icons" from settings.xml */
  if (!XBMC->GetSetting("channel_icons", &g_bChannelIcons))
  {
    /* If setting is unknown fallback to defaults */
    XBMC->Log(LOG_ERROR, "Couldn't get 'channel_icons' setting, falling back to '%b' as default", DEFAULT_CHANNEL_ICONS);
    g_bChannelIcons = DEFAULT_CHANNEL_ICONS;
  }

  /* Read setting "recording_icons" from settings.xml */
  if (!XBMC->GetSetting("recording_icons", &g_bRecordingIcons))
  {
    /* If setting is unknown fallback to defaults */
    XBMC->Log(LOG_ERROR, "Couldn't get 'recording_icons' setting, falling back to '%b' as default", DEFAULT_RECORDING_ICONS);
    g_bRecordingIcons = DEFAULT_RECORDING_ICONS;
  }

  /* Read setting "limit_tune_attempts" from settings.xml */
  if (!XBMC->GetSetting("limit_tune_attempts", &g_bLimitTuneAttempts))
  {
    /* If setting is unknown fallback to defaults */
    XBMC->Log(LOG_ERROR, "Couldn't get 'limit_tune_attempts' setting, falling back to '%b' as default", DEFAULT_LIMIT_TUNE_ATTEMPTS);
    g_bLimitTuneAttempts = DEFAULT_LIMIT_TUNE_ATTEMPTS;
  }

  free (buffer);
  XBMC->Log(LOG_DEBUG, "Loading settings...done");

  // Create our addon
  XBMC->Log(LOG_DEBUG, "Creating MythTV client...");
  g_client = new PVRClientMythTV();
  if (!g_client->Connect())
  {
    switch(g_client->GetConnectionError())
    {
      case PVRClientMythTV::CONN_ERROR_UNKNOWN_VERSION:
      {
        // HEADING: Connection failed
        // Failed to connect the MythTV backend with the known protocol versions.
        // Do you want to retry ?
        std::string msg = XBMC->GetLocalizedString(30300);
        msg.append("\n").append(XBMC->GetLocalizedString(30113));
        GUIDialogYesNo dialog(XBMC->GetLocalizedString(30112), msg.c_str(), 1);
        dialog.Open();
        if (dialog.IsNo())
          m_CurStatus = ADDON_STATUS_PERMANENT_FAILURE;
        else
          m_CurStatus = ADDON_STATUS_NEED_SETTINGS;
        break;
      }
      case PVRClientMythTV::CONN_ERROR_API_UNAVAILABLE:
      {
        // HEADING: Connection failed
        // Failed to connect the API services of MythTV backend. Please check your PIN code or backend setup.
        // Do you want to retry ?
        std::string msg = XBMC->GetLocalizedString(30301);
        msg.append("\n").append(XBMC->GetLocalizedString(30113));
        GUIDialogYesNo dialog(XBMC->GetLocalizedString(30112), msg.c_str(), 1);
        dialog.Open();
        if (dialog.IsNo())
          m_CurStatus = ADDON_STATUS_PERMANENT_FAILURE;
        else
          m_CurStatus = ADDON_STATUS_NEED_SETTINGS;
        break;
      }
      default:
        if (g_bNotifyAddonFailure)
        {
          XBMC->QueueNotification(QUEUE_ERROR, XBMC->GetLocalizedString(30304)); // No response from MythTV backend
          g_bNotifyAddonFailure = false; // No more notification
        }
        m_CurStatus = ADDON_STATUS_NEED_SETTINGS;
    }
    SAFE_DELETE(g_client);
    SAFE_DELETE(CODEC);
    SAFE_DELETE(GUI);
    SAFE_DELETE(PVR);
    SAFE_DELETE(XBMC);
    return m_CurStatus;
  }
  XBMC->Log(LOG_DEBUG, "Creating MythTV client...done");

  /* Read setting "LiveTV Priority" from backend database */
  bool savedLiveTVPriority;
  if (!XBMC->GetSetting("livetv_priority", &savedLiveTVPriority))
    savedLiveTVPriority = DEFAULT_LIVETV_PRIORITY;
  g_bLiveTVPriority = g_client->GetLiveTVPriority();
  if (g_bLiveTVPriority != savedLiveTVPriority)
  {
    g_client->SetLiveTVPriority(savedLiveTVPriority);
  }

  XBMC->Log(LOG_DEBUG, "Creating menu hooks...");
  PVR_MENUHOOK menuHookDeleteAndRerecord;
  menuHookDeleteAndRerecord.category = PVR_MENUHOOK_RECORDING;
  menuHookDeleteAndRerecord.iHookId = MENUHOOK_REC_DELETE_AND_RERECORD;
  menuHookDeleteAndRerecord.iLocalizedStringId = 30411;
  PVR->AddMenuHook(&menuHookDeleteAndRerecord);

  PVR_MENUHOOK menuHookKeepLiveTVRec;
  menuHookKeepLiveTVRec.category = PVR_MENUHOOK_RECORDING;
  menuHookKeepLiveTVRec.iHookId = MENUHOOK_KEEP_LIVETV_RECORDING;
  menuHookKeepLiveTVRec.iLocalizedStringId = 30412;
  PVR->AddMenuHook(&menuHookKeepLiveTVRec);

  PVR_MENUHOOK menuhookSettingShowNR;
  menuhookSettingShowNR.category = PVR_MENUHOOK_SETTING;
  menuhookSettingShowNR.iHookId = MENUHOOK_SHOW_HIDE_NOT_RECORDING;
  menuhookSettingShowNR.iLocalizedStringId = 30421;
  PVR->AddMenuHook(&menuhookSettingShowNR);

  PVR_MENUHOOK menuhookEpgRec1;
  menuhookEpgRec1.category = PVR_MENUHOOK_EPG;
  menuhookEpgRec1.iHookId = MENUHOOK_EPG_REC_CHAN_ALL_SHOWINGS;
  menuhookEpgRec1.iLocalizedStringId = 30431;
  PVR->AddMenuHook(&menuhookEpgRec1);

  PVR_MENUHOOK menuhookEpgRec2;
  menuhookEpgRec2.category = PVR_MENUHOOK_EPG;
  menuhookEpgRec2.iHookId = MENUHOOK_EPG_REC_CHAN_WEEKLY;
  menuhookEpgRec2.iLocalizedStringId = 30432;
  PVR->AddMenuHook(&menuhookEpgRec2);

  PVR_MENUHOOK menuhookEpgRec3;
  menuhookEpgRec3.category = PVR_MENUHOOK_EPG;
  menuhookEpgRec3.iHookId = MENUHOOK_EPG_REC_CHAN_DAILY;
  menuhookEpgRec3.iLocalizedStringId = 30433;
  PVR->AddMenuHook(&menuhookEpgRec3);

  PVR_MENUHOOK menuhookEpgRec4;
  menuhookEpgRec4.category = PVR_MENUHOOK_EPG;
  menuhookEpgRec4.iHookId = MENUHOOK_EPG_REC_ONE_SHOWING;
  menuhookEpgRec4.iLocalizedStringId = 30434;
  PVR->AddMenuHook(&menuhookEpgRec4);

  PVR_MENUHOOK menuhookEpgRec5;
  menuhookEpgRec5.category = PVR_MENUHOOK_EPG;
  menuhookEpgRec5.iHookId = MENUHOOK_EPG_REC_NEW_EPISODES;
  menuhookEpgRec5.iLocalizedStringId = 30435;
  PVR->AddMenuHook(&menuhookEpgRec5);

  PVR_MENUHOOK menuhookSettingRCI;
  menuhookSettingRCI.category = PVR_MENUHOOK_SETTING;
  menuhookSettingRCI.iHookId = MENUHOOK_REFRESH_CHANNEL_ICONS;
  menuhookSettingRCI.iLocalizedStringId = 30422;
  PVR->AddMenuHook(&menuhookSettingRCI);

  XBMC->Log(LOG_DEBUG, "Creating menu hooks...done");

  XBMC->Log(LOG_DEBUG, "Addon created successfully");
  m_CurStatus = ADDON_STATUS_OK;
  g_bCreated = true;
  return m_CurStatus;
}

void ADDON_Destroy()
{
  if (g_bCreated)
  {
    g_bCreated = false;
    SAFE_DELETE(g_client);
    SAFE_DELETE(CODEC);
    SAFE_DELETE(PVR);
    SAFE_DELETE(XBMC);
    SAFE_DELETE(GUI);
  }
  m_CurStatus = ADDON_STATUS_UNKNOWN;
}

void ADDON_Announce(const char *flag, const char *sender, const char *message, const void *data)
{
  (void)data;
  XBMC->Log(LOG_INFO, "Received announcement: %s, %s, %s", flag, sender, message);

  if (g_client == NULL)
    return;

  if (strcmp("xbmc", sender) == 0)
  {
    if (strcmp("System", flag) == 0)
    {
      if (strcmp("OnSleep", message) == 0)
        g_client->OnSleep();
      else if (strcmp("OnWake", message) == 0)
        g_client->OnWake();
    }
    else if (strcmp("GUI", flag) == 0)
    {
      if (strcmp("OnScreensaverDeactivated", message) == 0)
        g_client->OnActivatedGUI();
      else if (strcmp("OnScreensaverActivated", message) == 0)
        g_client->OnDeactivatedGUI();
    }
  }
}

ADDON_STATUS ADDON_GetStatus()
{
  return m_CurStatus;
}

bool ADDON_HasSettings()
{
  return true;
}

unsigned int ADDON_GetSettings(ADDON_StructSetting ***sSet)
{
  (void)sSet;
  return 0;
}

ADDON_STATUS ADDON_SetSetting(const char *settingName, const void *settingValue)
{
  if (!g_bCreated)
    return ADDON_STATUS_OK;

  std::string str = settingName;

  if (str == "host")
  {
    std::string tmp_sHostname;
    XBMC->Log(LOG_INFO, "Changed Setting 'host' from %s to %s", g_szMythHostname.c_str(), (const char*)settingValue);
    tmp_sHostname = g_szMythHostname;
    g_szMythHostname = (const char*)settingValue;
    if (tmp_sHostname != g_szMythHostname)
    {
      g_bNotifyAddonFailure = true;
      return ADDON_STATUS_NEED_RESTART;
    }
  }
  else if (str == "port")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'port' from %u to %u", g_iProtoPort, *(int*)settingValue);
    if (g_iProtoPort != *(int*)settingValue)
    {
      g_iProtoPort = *(int*)settingValue;
      g_bNotifyAddonFailure = true;
      return ADDON_STATUS_NEED_RESTART;
    }
  }
  else if (str == "wsport")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'wsport' from %u to %u", g_iWSApiPort, *(int*)settingValue);
    if (g_iWSApiPort != *(int*)settingValue)
    {
      g_iWSApiPort = *(int*)settingValue;
      g_bNotifyAddonFailure = true;
      return ADDON_STATUS_NEED_RESTART;
    }
  }
  else if (str == "wssecuritypin")
  {
    std::string tmp_sWSSecurityPin;
    XBMC->Log(LOG_INFO, "Changed Setting 'wssecuritypin' from %s to %s", g_szWSSecurityPin.c_str(), (const char*)settingValue);
    tmp_sWSSecurityPin = g_szWSSecurityPin;
    g_szWSSecurityPin = (const char*)settingValue;
    if (tmp_sWSSecurityPin != g_szWSSecurityPin)
      return ADDON_STATUS_NEED_RESTART;
  }
  else if (str == "demuxing")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'demuxing' from %u to %u", g_bDemuxing, *(bool*)settingValue);
    if (g_bDemuxing != *(bool*)settingValue)
      return ADDON_STATUS_NEED_RESTART;
  }
  else if (str == "channel_icons")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'channel_icons' from %u to %u", g_bChannelIcons, *(bool*)settingValue);
    if (g_bChannelIcons != *(bool*)settingValue)
      return ADDON_STATUS_NEED_RESTART;
  }
  else if (str == "recording_icons")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'recording_icons' from %u to %u", g_bRecordingIcons, *(bool*)settingValue);
    if (g_bRecordingIcons != *(bool*)settingValue)
      return ADDON_STATUS_NEED_RESTART;
  }
  else if (str == "host_ether")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'host_ether' from %s to %s", g_szMythHostEther.c_str(), (const char*)settingValue);
    g_szMythHostEther = (const char*)settingValue;
  }
  else if (str == "extradebug")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'extra debug' from %u to %u", g_bExtraDebug, *(bool*)settingValue);
    if (g_bExtraDebug != *(bool*)settingValue)
    {
      g_bExtraDebug = *(bool*)settingValue;
      if (g_client)
        g_client->SetDebug();
    }
  }
  else if (str == "livetv")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'livetv' from %u to %u", g_bLiveTV, *(bool*)settingValue);
    if (g_bLiveTV != *(bool*)settingValue)
      g_bLiveTV = *(bool*)settingValue;
  }
  else if (str == "livetv_priority")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'extra debug' from %u to %u", g_bLiveTVPriority, *(bool*)settingValue);
    if (g_bLiveTVPriority != *(bool*) settingValue && m_CurStatus != ADDON_STATUS_LOST_CONNECTION)
    {
      g_bLiveTVPriority = *(bool*)settingValue;
      if (g_client)
        g_client->SetLiveTVPriority(g_bLiveTVPriority);
    }
  }
  else if (str == "rec_template_provider")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'rec_template_provider' from %u to %u", g_iRecTemplateType, *(int*)settingValue);
    if (g_iRecTemplateType != *(int*)settingValue)
      g_iRecTemplateType = *(int*)settingValue;
  }
  else if (str == "rec_autometadata")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'rec_autometadata' from %u to %u", g_bRecAutoMetadata, *(bool*)settingValue);
    if (g_bRecAutoMetadata != *(bool*)settingValue)
      g_bRecAutoMetadata = *(bool*)settingValue;
  }
  else if (str == "rec_autocommflag")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'rec_autocommflag' from %u to %u", g_bRecAutoCommFlag, *(bool*)settingValue);
    if (g_bRecAutoCommFlag != *(bool*)settingValue)
      g_bRecAutoCommFlag = *(bool*)settingValue;
  }
  else if (str == "rec_autotranscode")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'rec_autotranscode' from %u to %u", g_bRecAutoTranscode, *(bool*)settingValue);
    if (g_bRecAutoTranscode != *(bool*)settingValue)
      g_bRecAutoTranscode = *(bool*)settingValue;
  }
  else if (str == "rec_transcoder")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'rec_transcoder' from %u to %u", g_iRecTranscoder, *(int*)settingValue);
    if (g_iRecTranscoder != *(int*)settingValue)
      g_iRecTranscoder = *(int*)settingValue;
  }
  else if (str == "rec_autorunjob1")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'rec_autorunjob1' from %u to %u", g_bRecAutoRunJob1, *(bool*)settingValue);
    if (g_bRecAutoRunJob1 != *(bool*)settingValue)
      g_bRecAutoRunJob1 = *(bool*)settingValue;
  }
  else if (str == "rec_autorunjob2")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'rec_autorunjob2' from %u to %u", g_bRecAutoRunJob2, *(bool*)settingValue);
    if (g_bRecAutoRunJob2 != *(bool*)settingValue)
      g_bRecAutoRunJob2 = *(bool*)settingValue;
  }
  else if (str == "rec_autorunjob3")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'rec_autorunjob3' from %u to %u", g_bRecAutoRunJob3, *(bool*)settingValue);
    if (g_bRecAutoRunJob3 != *(bool*)settingValue)
      g_bRecAutoRunJob3 = *(bool*)settingValue;
  }
  else if (str == "rec_autorunjob4")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'rec_autorunjob4' from %u to %u", g_bRecAutoRunJob4, *(bool*)settingValue);
    if (g_bRecAutoRunJob4 != *(bool*)settingValue)
      g_bRecAutoRunJob4 = *(bool*)settingValue;
  }
  else if (str == "rec_autoexpire")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'rec_autoexpire' from %u to %u", g_bRecAutoExpire, *(bool*)settingValue);
    if (g_bRecAutoExpire != *(bool*)settingValue)
      g_bRecAutoExpire = *(bool*)settingValue;
  }
  else if (str == "tunedelay")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'tunedelay' from %d to %d", g_iTuneDelay, *(int*)settingValue);
    if (g_iTuneDelay != *(int*)settingValue)
      g_iTuneDelay = *(int*)settingValue;
  }
  else if (str == "group_recordings")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'group_recordings' from %u to %u", g_iGroupRecordings, *(int*)settingValue);
    if (g_iGroupRecordings != *(int*)settingValue)
    {
      g_iGroupRecordings = *(int*)settingValue;
      PVR->TriggerRecordingUpdate();
    }
  }
  else if (str == "enable_edl")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'enable_edl' from %u to %u", g_iEnableEDL, *(int*)settingValue);
    if (g_iEnableEDL != *(int*)settingValue)
      g_iEnableEDL = *(int*)settingValue;
  }
  else if (str == "block_shutdown")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'block_shutdown' from %u to %u", g_bBlockMythShutdown, *(bool*)settingValue);
    if (g_bBlockMythShutdown != *(bool*)settingValue)
    {
      g_bBlockMythShutdown = *(bool*)settingValue;
      if (g_client)
        g_bBlockMythShutdown ? g_client->BlockBackendShutdown() : g_client->AllowBackendShutdown();
    }
  }
  else if (str == "limit_tune_attempts")
  {
    XBMC->Log(LOG_INFO, "Changed Setting 'limit_tune_attempts' from %u to %u", g_bLimitTuneAttempts, *(bool*)settingValue);
    if (g_bLimitTuneAttempts != *(bool*)settingValue)
      g_bLimitTuneAttempts = *(bool*)settingValue;
  }
  return ADDON_STATUS_OK;
}

void ADDON_Stop()
{
  //ADDON_Destroy();
}

void ADDON_FreeSettings()
{
  return;
}


/***********************************************************
 * PVR Client AddOn specific public library functions
 ***********************************************************/

const char* GetPVRAPIVersion(void)
{
  static const char *strApiVersion = XBMC_PVR_API_VERSION;
  return strApiVersion;
}

const char* GetMininumPVRAPIVersion(void)
{
  static const char *strMinApiVersion = XBMC_PVR_MIN_API_VERSION;
  return strMinApiVersion;
}

const char* GetGUIAPIVersion(void)
{
  static const char *strGuiApiVersion = KODI_GUILIB_API_VERSION;
  return strGuiApiVersion;
}

const char* GetMininumGUIAPIVersion(void)
{
  static const char *strMinGuiApiVersion = KODI_GUILIB_MIN_API_VERSION;
  return strMinGuiApiVersion;
}

PVR_ERROR GetAddonCapabilities(PVR_ADDON_CAPABILITIES *pCapabilities)
{
  if (g_client != NULL)
  {
    unsigned version = g_client->GetBackendAPIVersion();
    pCapabilities->bSupportsTV                    = g_bLiveTV;
    pCapabilities->bSupportsRadio                 = g_bLiveTV;
    pCapabilities->bSupportsChannelGroups         = true;
    pCapabilities->bSupportsChannelScan           = false;
    pCapabilities->bSupportsEPG                   = true;
    pCapabilities->bSupportsTimers                = true;

    pCapabilities->bHandlesInputStream            = true;
    pCapabilities->bHandlesDemuxing               = g_bDemuxing;

    pCapabilities->bSupportsRecordings            = true;
    pCapabilities->bSupportsRecordingsUndelete    = true;
    pCapabilities->bSupportsRecordingPlayCount    = (version < 80 ? false : true);
    pCapabilities->bSupportsLastPlayedPosition    = false;
    pCapabilities->bSupportsRecordingEdl          = true;
    return PVR_ERROR_NO_ERROR;
  }
  else
  {
    return PVR_ERROR_FAILED;
  }
}

const char *GetBackendName()
{
  return g_client->GetBackendName();
}

const char *GetBackendVersion()
{
  return g_client->GetBackendVersion();
}

const char *GetConnectionString()
{
  return g_client->GetConnectionString();
}

const char *GetBackendHostname(void)
{
  return g_szMythHostname.c_str();
}

PVR_ERROR GetDriveSpace(long long *iTotal, long long *iUsed)
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;

  return g_client->GetDriveSpace(iTotal, iUsed);
}

PVR_ERROR OpenDialogChannelScan()
{
  return PVR_ERROR_FAILED;
}

PVR_ERROR CallMenuHook(const PVR_MENUHOOK &menuhook, const PVR_MENUHOOK_DATA &item)
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;

  return g_client->CallMenuHook(menuhook, item);
}

/*
 * PVR EPG Functions
 */

PVR_ERROR GetEPGForChannel(ADDON_HANDLE handle, const PVR_CHANNEL &channel, time_t iStart, time_t iEnd)
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;

  return g_client->GetEPGForChannel(handle, channel, iStart, iEnd);
}

/*
 * PVR Channel Functions
 */

unsigned int GetChannelSwitchDelay(void)
{
  return 0;
}

int GetChannelsAmount()
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;

  return g_client->GetNumChannels();
}

PVR_ERROR GetChannels(ADDON_HANDLE handle, bool bRadio)
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;

  return g_client->GetChannels(handle, bRadio);
}

PVR_ERROR DeleteChannel(const PVR_CHANNEL &channel)
{
  (void)channel;
  return PVR_ERROR_NOT_IMPLEMENTED;
}

PVR_ERROR RenameChannel(const PVR_CHANNEL &channel)
{
  (void)channel;
  return PVR_ERROR_NOT_IMPLEMENTED;
}

PVR_ERROR MoveChannel(const PVR_CHANNEL &channel)
{
  (void)channel;
  return PVR_ERROR_NOT_IMPLEMENTED;
}

PVR_ERROR OpenDialogChannelSettings(const PVR_CHANNEL &channel)
{
  (void)channel;
  return PVR_ERROR_NOT_IMPLEMENTED;
}

PVR_ERROR OpenDialogChannelAdd(const PVR_CHANNEL &channel)
{
  (void)channel;
  return PVR_ERROR_NOT_IMPLEMENTED;
}

int GetChannelGroupsAmount(void)
{
  if (g_client == NULL)
    return -1;

  return g_client->GetChannelGroupsAmount();
}

PVR_ERROR GetChannelGroups(ADDON_HANDLE handle, bool bRadio)
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;

  return g_client->GetChannelGroups(handle, bRadio);
}

PVR_ERROR GetChannelGroupMembers(ADDON_HANDLE handle, const PVR_CHANNEL_GROUP &group){
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;

  return g_client->GetChannelGroupMembers(handle, group);
}


/*
 * PVR Recording Functions
 */

int GetRecordingsAmount(bool deleted)
{
  if (g_client == NULL)
    return 0;
  if (deleted)
    return g_client->GetDeletedRecordingsAmount();
  return g_client->GetRecordingsAmount();
}

PVR_ERROR GetRecordings(ADDON_HANDLE handle, bool deleted)
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;
  if (deleted)
    return g_client->GetDeletedRecordings(handle);
  return g_client->GetRecordings(handle);
}

PVR_ERROR DeleteRecording(const PVR_RECORDING &recording)
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;

  return g_client->DeleteRecording(recording);
}

PVR_ERROR RenameRecording(const PVR_RECORDING &recording)
{
  (void)recording;
  return PVR_ERROR_NOT_IMPLEMENTED;
}

PVR_ERROR SetRecordingPlayCount(const PVR_RECORDING &recording, int count)
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;
  return g_client->SetRecordingPlayCount(recording, count);
}

PVR_ERROR SetRecordingLastPlayedPosition(const PVR_RECORDING &recording, int lastplayedposition)
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;
  (void)recording;
  (void)lastplayedposition;
  return PVR_ERROR_NOT_IMPLEMENTED;
}

int GetRecordingLastPlayedPosition(const PVR_RECORDING &recording)
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;
  (void)recording;
  return -1;
}

PVR_ERROR GetRecordingEdl(const PVR_RECORDING &recording, PVR_EDL_ENTRY entries[], int *size)
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;
  return g_client->GetRecordingEdl(recording, entries, size);
}

PVR_ERROR UndeleteRecording(const PVR_RECORDING& recording)
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;
  return g_client->UndeleteRecording(recording);
}

PVR_ERROR DeleteAllRecordingsFromTrash()
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;
  return g_client->PurgeDeletedRecordings();
}

/*
 * PVR Timer Functions
 */

int GetTimersAmount(void)
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;

  return g_client->GetTimersAmount();
}

PVR_ERROR GetTimers(ADDON_HANDLE handle)
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;

  return g_client->GetTimers(handle);
}

PVR_ERROR AddTimer(const PVR_TIMER &timer)
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;

  return g_client->AddTimer(timer);
}

PVR_ERROR DeleteTimer(const PVR_TIMER &timer, bool bForceDelete)
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;

  return g_client->DeleteTimer(timer,bForceDelete);
}

PVR_ERROR UpdateTimer(const PVR_TIMER &timer)
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;

  return g_client->UpdateTimer(timer);
}


/*
 * PVR Live Stream Functions
 */

bool OpenLiveStream(const PVR_CHANNEL &channel)
{
  if (g_client == NULL)
    return false;

  return g_client->OpenLiveStream(channel);
}

void CloseLiveStream(void)
{
  if (g_client == NULL)
    return;

  g_client->CloseLiveStream();
}

int ReadLiveStream(unsigned char *pBuffer, unsigned int iBufferSize)
{
  if (g_client == NULL)
    return -1;

  int dataread = g_client->ReadLiveStream(pBuffer, iBufferSize);
  if (dataread < 0)
  {
    XBMC->Log(LOG_ERROR,"%s: Failed to read liveStream. Errorcode: %d!", __FUNCTION__, dataread);
    dataread = 0;
  }
  return dataread;
}

int GetCurrentClientChannel()
{
  if (g_client == NULL)
    return -1;

  return g_client->GetCurrentClientChannel();
}

bool SwitchChannel(const PVR_CHANNEL &channel)
{
  if (g_client == NULL)
    return false;

  return g_client->SwitchChannel(channel);
}

PVR_ERROR SignalStatus(PVR_SIGNAL_STATUS &signalStatus)
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;

  return g_client->SignalStatus(signalStatus);
}

void PauseStream(bool bPaused)
{
  (void)bPaused;
}

bool CanPauseStream(void)
{
  return true;
}

bool CanSeekStream(void)
{
  return true;
}

long long SeekLiveStream(long long iPosition, int iWhence)
{
  if (g_client == NULL)
    return -1;

  return g_client->SeekLiveStream(iPosition,iWhence);
}

long long PositionLiveStream(void)
{
  if (g_client == NULL)
    return -1;

  return g_client->SeekLiveStream(0,SEEK_CUR);
}

long long LengthLiveStream(void)
{
  if (g_client == NULL)
    return -1;

  return g_client->LengthLiveStream();
}


/*
 * PVR Recording Stream Functions
 */

bool OpenRecordedStream(const PVR_RECORDING &recinfo)
{
  if (g_client == NULL)
    return false;

  return g_client->OpenRecordedStream(recinfo);
}

void CloseRecordedStream(void)
{
  if (g_client == NULL)
    return;

  g_client->CloseRecordedStream();
}

int ReadRecordedStream(unsigned char *pBuffer, unsigned int iBufferSize)
{
  if (g_client == NULL)
    return -1;

  return g_client->ReadRecordedStream(pBuffer, iBufferSize);
}

long long SeekRecordedStream(long long iPosition, int iWhence)
{
  if (g_client == NULL)
    return -1;

  return g_client->SeekRecordedStream(iPosition, iWhence);
}

long long PositionRecordedStream(void)
{
  if (g_client == NULL)
    return -1;

  return g_client->SeekRecordedStream(0, SEEK_CUR);
}

long long LengthRecordedStream(void)
{
  if (g_client == NULL)
    return -1;

  return g_client->LengthRecordedStream();
}


/*
 * PVR Demux Functions
 */

PVR_ERROR GetStreamProperties(PVR_STREAM_PROPERTIES* pProperties)
{
  if (g_client == NULL)
    return PVR_ERROR_SERVER_ERROR;

  return g_client->GetStreamProperties(pProperties);
}

void DemuxAbort(void)
{
  if (g_client != NULL)
    g_client->DemuxAbort();
}

DemuxPacket* DemuxRead(void)
{
  if (g_client == NULL)
    return NULL;

  return g_client->DemuxRead();
}

void DemuxFlush(void)
{
  if (g_client != NULL)
    g_client->DemuxFlush();
}

bool SeekTime(int time, bool backwards, double *startpts)
{
  if (g_client != NULL)
    return g_client->SeekTime(time, backwards, startpts);
  return false;
}


/*
 * PVR Timeshift Functions
 */

time_t GetPlayingTime()
{
  if (g_client != NULL)
    return g_client->GetPlayingTime();
  return 0;
}

time_t GetBufferTimeStart()
{
  if (g_client != NULL)
    return g_client->GetBufferTimeStart();
  return 0;
}

time_t GetBufferTimeEnd()
{
  if (g_client != NULL)
    return g_client->GetBufferTimeEnd();
  return 0;
}

/*
 * Unused API Functions
 */

void DemuxReset() {}
const char * GetLiveStreamURL(const PVR_CHANNEL &) { return ""; }
void SetSpeed(int) {};

} //end extern "C"
