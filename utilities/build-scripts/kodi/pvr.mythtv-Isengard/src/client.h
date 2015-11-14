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

#ifndef CLIENT_H
#define CLIENT_H

#include <string>
#include <kodi/libXBMC_addon.h>
#include <kodi/libXBMC_pvr.h>
#include <kodi/libKODI_guilib.h>
#include <kodi/libXBMC_codec.h>

#define LIVETV_CONFLICT_STRATEGY_HASLATER   0
#define LIVETV_CONFLICT_STRATEGY_STOPTV     1
#define LIVETV_CONFLICT_STRATEGY_CANCELREC  2

#define DEFAULT_HOST                        "127.0.0.1"
#define DEFAULT_EXTRA_DEBUG                 false
#define DEFAULT_LIVETV_PRIORITY             true
#define DEFAULT_LIVETV_CONFLICT_STRATEGY    LIVETV_CONFLICT_STRATEGY_HASLATER
#define DEFAULT_LIVETV                      true
#define DEFAULT_PROTO_PORT                  6543
#define DEFAULT_WSAPI_PORT                  6544
#define DEFAULT_WSAPI_SECURITY_PIN          "0000"
#define DEFAULT_CHANNEL_ICONS               true
#define DEFAULT_RECORDING_ICONS             true
#define DEFAULT_RECORD_TEMPLATE             1

#define SUBTITLE_SEPARATOR                  " - "

#define MENUHOOK_REC_DELETE_AND_RERECORD    1
#define MENUHOOK_KEEP_LIVETV_RECORDING      2
#define MENUHOOK_SHOW_HIDE_NOT_RECORDING    3
#define MENUHOOK_EPG_REC_CHAN_ALL_SHOWINGS  4
#define MENUHOOK_EPG_REC_CHAN_WEEKLY        5
#define MENUHOOK_EPG_REC_CHAN_DAILY         6
#define MENUHOOK_EPG_REC_ONE_SHOWING        7
#define MENUHOOK_EPG_REC_NEW_EPISODES       8
#define MENUHOOK_REFRESH_CHANNEL_ICONS      9

#define DEFAULT_HANDLE_DEMUXING             false
#define DEFAULT_TUNE_DELAY                  5
#define GROUP_RECORDINGS_ALWAYS             0
#define GROUP_RECORDINGS_ONLY_FOR_SERIES    1
#define GROUP_RECORDINGS_NEVER              2
#define ENABLE_EDL_ALWAYS                   0
#define ENABLE_EDL_DIALOG                   1
#define ENABLE_EDL_NEVER                    2
#define DEFAULT_BLOCK_SHUTDOWN              true
#define DEFAULT_LIMIT_TUNE_ATTEMPTS         true

/*!
 * @brief PVR macros for string exchange
 */
#define PVR_STRCPY(dest, source) do { strncpy(dest, source, sizeof(dest)-1); dest[sizeof(dest)-1] = '\0'; } while(0)
#define PVR_STRCLR(dest) memset(dest, 0, sizeof(dest))

/** Delete macros that make the pointer NULL again */
#define SAFE_DELETE(p)       if ((p) != NULL) { delete (p);    (p) = NULL; }
#define SAFE_DELETE_ARRAY(p) if ((p) != NULL) { delete[] (p);  (p) = NULL; }

extern bool         g_bCreated;                 ///< Shows that the Create function was successfully called
extern int          g_iClientID;                ///< The PVR client ID used by XBMC for this driver
extern std::string  g_szUserPath;               ///< The Path to the user directory inside user profile
extern std::string  g_szClientPath;             ///< The Path where this driver is located

/* Client Settings */
extern bool         g_bNotifyAddonFailure;      ///< Notify user after failure of Create function
extern std::string  g_szMythHostname;           ///< The Host name or IP of the mythtv server
extern std::string  g_szMythHostEther;          ///< The Host MAC address of the mythtv server
extern int          g_iProtoPort;               ///< The mythtv protocol port (default is 6543)
extern int          g_iWSApiPort;               ///< The mythtv service API port (default is 6544)
extern std::string  g_szWSSecurityPin;          ///< The default security pin for the mythtv wsapi
extern bool         g_bExtraDebug;              ///< Debug logging
extern bool         g_bLiveTV;                  ///< LiveTV support (or recordings only)
extern bool         g_bLiveTVPriority;          ///< MythTV Backend setting to allow live TV to move scheduled shows
extern int          g_iLiveTVConflictStrategy;  ///< Live TV conflict resolving strategy (0=Has later, 1=Stop TV, 2=Cancel recording)
extern bool         g_bChannelIcons;            ///< Load Channel Icons
extern bool         g_bRecordingIcons;          ///< Load Recording Icons (Fanart/Thumbnails)
extern int          g_iRecTemplateType;         ///< Template type for new record (0=Internal, 1=MythTV)
///@{
/// Internal Record template
extern bool         g_bRecAutoMetadata;
extern bool         g_bRecAutoCommFlag;
extern bool         g_bRecAutoTranscode;
extern bool         g_bRecAutoRunJob1;
extern bool         g_bRecAutoRunJob2;
extern bool         g_bRecAutoRunJob3;
extern bool         g_bRecAutoRunJob4;
extern bool         g_bRecAutoExpire;
extern int          g_iRecTranscoder;
///@}
extern bool         g_bDemuxing;
extern int          g_iTuneDelay;
extern int          g_iGroupRecordings;
extern int          g_iEnableEDL;
extern bool         g_bBlockMythShutdown;
extern bool         g_bLimitTuneAttempts;       ///< Limit channel tuning attempts to first card

extern ADDON::CHelper_libXBMC_addon *XBMC;
extern CHelper_libXBMC_pvr          *PVR;
extern CHelper_libKODI_guilib       *GUI;
extern CHelper_libXBMC_codec        *CODEC;

#endif /* CLIENT_H */
