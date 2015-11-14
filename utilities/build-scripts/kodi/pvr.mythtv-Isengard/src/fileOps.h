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

#include "cppmyth/MythChannel.h"
#include "cppmyth/MythProgramInfo.h"

#include <mythwsapi.h>
#include <platform/threads/threads.h>

#include <string>
#include <vector>
#include <list>
#include <map>

class FileConsumer
{
public:
  virtual ~FileConsumer() {};
  virtual void HandleCleanedCache() = 0;
};

class FileOps : public PLATFORM::CThread
{
public:
  enum FileType
  {
    FileTypePreview,
    FileTypeThumbnail,
    FileTypeCoverart,
    FileTypeFanart,
    FileTypeChannelIcon,
    FileTypeBanner,
    FileTypeScreenshot,
    FileTypePoster,
    FileTypeBackcover,
    FileTypeInsidecover,
    FileTypeCDImage
  };

  static std::vector<FileType> GetFileTypes()
  {
    std::vector<FileType> ret;
    ret.push_back(FileTypeChannelIcon);
    ret.push_back(FileTypeThumbnail);
    ret.push_back(FileTypeCoverart);
    ret.push_back(FileTypeFanart);
    ret.push_back(FileTypeBanner);
    ret.push_back(FileTypeScreenshot);
    ret.push_back(FileTypePoster);
    ret.push_back(FileTypeBackcover);
    ret.push_back(FileTypeInsidecover);
    ret.push_back(FileTypeCDImage);
    return ret;
  }

  static const char *GetTypeNameByFileType(FileType fileType)
  {
    switch(fileType)
    {
    case FileTypeChannelIcon: return "channelIcon";
    case FileTypeThumbnail: return "thumbnail";
    case FileTypeCoverart: return "coverart";
    case FileTypeFanart: return "fanart";
    case FileTypeBanner: return "banner";
    case FileTypeScreenshot: return "screenshot";
    case FileTypePoster: return "poster";
    case FileTypeBackcover: return "backcover";
    case FileTypeInsidecover: return "insidecover";
    case FileTypeCDImage: return "cdimage";
    default: return "";
    }
  }

  static const int c_timeoutProcess              = 10;       // Wake the thread every 10s
  static const int c_maximumAttemptsOnReadError  = 3;        // Retry when reading file failed
  static const int c_cacheMaxAge                 = 2635200;  // Clean cache every 2635200s (30.5 days)

  FileOps(FileConsumer *consumer, const std::string& server, unsigned wsapiport, const std::string& wsapiSecurityPin);
  virtual ~FileOps();

  std::string GetChannelIconPath(const MythChannel& channel);
  std::string GetPreviewIconPath(const MythProgramInfo& recording);
  std::string GetArtworkPath(const MythProgramInfo& recording, FileType type);

  void Suspend();
  void Resume();

  void CleanChannelIcons();

protected:
  void *Process();

  bool CheckFile(const std::string &localFilename);
  void *OpenFile(const std::string &localFilename);
  bool CacheFile(void *file, Myth::Stream *source);
  void InitBasePath();
  void CleanCache();

  static std::string GetFileName(const std::string& path, char separator = PATH_SEPARATOR_CHAR);
  static std::string GetDirectoryName(const std::string& path, char separator = PATH_SEPARATOR_CHAR);

  std::map<std::string, std::string> m_icons;
  std::map<std::string, std::string> m_preview;
  std::map<std::pair<FileType, std::string>, std::string> m_artworks;

  FileConsumer *m_consumer;
  Myth::WSAPI *m_wsapi;
  std::string m_localBasePath;
  std::string m_localBaseStampName;
  time_t m_localBaseStamp;

  struct JobItem {
    JobItem(const std::string& localFilename, FileType type, const MythProgramInfo& recording)
    : m_localFilename(localFilename)
    , m_fileType(type)
    , m_recording(recording)
    , m_errorCount(0)
    {
    }
    JobItem(const std::string& localFilename, FileType type, const MythChannel& channel)
    : m_localFilename(localFilename)
    , m_fileType(type)
    , m_channel(channel)
    , m_errorCount(0)
    {
    }

    std::string     m_localFilename;
    FileType        m_fileType;
    MythProgramInfo m_recording;
    MythChannel     m_channel;
    int             m_errorCount;
  };

  PLATFORM::CMutex m_lock;
  PLATFORM::CEvent m_queueContent;
  std::list<FileOps::JobItem> m_jobQueue;
};
