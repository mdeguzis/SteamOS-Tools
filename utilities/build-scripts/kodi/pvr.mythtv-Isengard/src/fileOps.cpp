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

#include "fileOps.h"
#include "client.h"

#include <stdio.h>
#include <ctime>
#include <algorithm>

#define FILEOPS_STREAM_BUFFER_SIZE    32000         // Buffer size to download artworks
#define FILEOPS_STAMP_FILENAME        "stamp"       // Base name for cache stamp file
#define FILEOPS_NOSTAMP               (time_t)(-1)
#define FILEOPS_CHANNEL_DUMMY_ICON    "channel.png"
#define FILEOPS_RECORDING_DUMMY_ICON  "recording.png"

using namespace ADDON;
using namespace PLATFORM;

FileOps::FileOps(FileConsumer *consumer, const std::string& server, unsigned wsapiport, const std::string& wsapiSecurityPin)
: CThread()
, m_consumer(consumer)
, m_wsapi(NULL)
, m_localBasePath(g_szUserPath.c_str())
, m_localBaseStampName()
, m_localBaseStamp(FILEOPS_NOSTAMP)
, m_queueContent()
, m_jobQueue()
{
  // Initialize base path for cache directories
  m_localBasePath.append("cache").append(PATH_SEPARATOR_STRING);
  m_localBaseStampName.append(m_localBasePath).append(FILEOPS_STAMP_FILENAME);
  InitBasePath();
  m_wsapi = new Myth::WSAPI(server, wsapiport, wsapiSecurityPin);
  CreateThread();
}

FileOps::~FileOps()
{
  StopThread(-1); // Set stopping. don't wait as we need to signal the thread first
  m_queueContent.Signal();
  StopThread(); // Wait for thread to stop
  SAFE_DELETE(m_wsapi);
}

std::string FileOps::GetChannelIconPath(const MythChannel& channel)
{
  if (channel.IsNull() || channel.Icon().empty())
    return "";
  if (!g_bChannelIcons)
    return g_szClientPath + PATH_SEPARATOR_STRING + "resources" + PATH_SEPARATOR_STRING + FILEOPS_CHANNEL_DUMMY_ICON;

  std::string uid = Myth::IdToString(channel.ID());
  if (g_bExtraDebug)
    XBMC->Log(LOG_DEBUG, "%s: channel: %s", __FUNCTION__, uid.c_str());

  // Check local directory
  std::map<std::string, std::string>::iterator it = m_icons.find(uid);
  if (it != m_icons.end())
    return it->second;

  // Determine filename
  std::string localFilename = m_localBasePath + GetTypeNameByFileType(FileTypeChannelIcon) + PATH_SEPARATOR_CHAR + uid;
  if (g_bExtraDebug)
    XBMC->Log(LOG_DEBUG, "%s: determined localFilename: %s", __FUNCTION__, localFilename.c_str());

  if (!CheckFile(localFilename.c_str()))
  {
    CLockObject lock(m_lock);
    FileOps::JobItem job(localFilename, FileTypeChannelIcon, channel);
    m_jobQueue.push_back(job);
    m_queueContent.Signal();
  }
  m_icons[uid] = localFilename;
  return localFilename;
}

std::string FileOps::GetPreviewIconPath(const MythProgramInfo& recording)
{
  if (recording.IsNull())
    return "";
  if (!g_bRecordingIcons)
    return g_szClientPath + PATH_SEPARATOR_STRING + "resources" + PATH_SEPARATOR_STRING + FILEOPS_RECORDING_DUMMY_ICON;

  std::string uid = recording.UID();
  if (g_bExtraDebug)
    XBMC->Log(LOG_DEBUG, "%s: preview: %s", __FUNCTION__, uid.c_str());

  // Check local directory
  std::map<std::string, std::string>::iterator it = m_preview.find(uid);
  if (it != m_preview.end())
    return it->second;

  // Determine local filename
  std::string localFilename = m_localBasePath + GetTypeNameByFileType(FileTypeThumbnail) + PATH_SEPARATOR_CHAR + uid;
  if (g_bExtraDebug)
    XBMC->Log(LOG_DEBUG, "%s: determined localFilename: %s", __FUNCTION__, localFilename.c_str());

  if (!CheckFile(localFilename.c_str()))
  {
    CLockObject lock(m_lock);
    FileOps::JobItem job(localFilename, FileTypeThumbnail, recording);
    m_jobQueue.push_back(job);
    m_queueContent.Signal();
  }
  m_preview[uid] = localFilename;
  return localFilename;
}

std::string FileOps::GetArtworkPath(const MythProgramInfo& recording, FileType type)
{
  if (recording.IsNull())
    return "";
  if (!g_bRecordingIcons)
    switch (type)
    {
    case FileTypePreview:
    case FileTypeCoverart:
      return g_szClientPath + PATH_SEPARATOR_STRING + "resources" + PATH_SEPARATOR_STRING + FILEOPS_RECORDING_DUMMY_ICON;
    default:
      return "";
    }

  std::string uid = recording.UID();
  if (g_bExtraDebug)
    XBMC->Log(LOG_DEBUG, "%s: %s: %s", __FUNCTION__, GetTypeNameByFileType(type), uid.c_str());

  // Check local directory
  std::pair<FileType, std::string> key = std::make_pair(type, uid);
  std::map<std::pair<FileType, std::string>, std::string>::iterator iter = m_artworks.find(key);
  if (iter != m_artworks.end())
    return iter->second;

  // Determine local filename
  std::string localFilename = m_localBasePath + GetTypeNameByFileType(type) + PATH_SEPARATOR_CHAR + uid.c_str();
  if (g_bExtraDebug)
    XBMC->Log(LOG_DEBUG, "%s: determined localFilename: %s", __FUNCTION__, localFilename.c_str());

  if (!CheckFile(localFilename.c_str()))
  {
    CLockObject lock(m_lock);
    FileOps::JobItem job(localFilename, type, recording);
    m_jobQueue.push_back(job);
    m_queueContent.Signal();
  }
  m_artworks[key] = localFilename;
  return localFilename;
}

void FileOps::Suspend()
{
  XBMC->Log(LOG_DEBUG, "%s", __FUNCTION__);
  if (IsRunning())
  {
    XBMC->Log(LOG_DEBUG, "%s: Stopping Thread", __FUNCTION__);
    StopThread(-1); // Set stopping. don't wait as we need to signal the thread first
    m_queueContent.Signal();
    StopThread(); // Wait for thread to stop
  }
}

void FileOps::Resume()
{
  XBMC->Log(LOG_DEBUG, "%s", __FUNCTION__);
  if (IsStopped())
  {
    XBMC->Log(LOG_DEBUG, "%s: Resuming Thread", __FUNCTION__);
    m_lock.Clear();
    CreateThread();
  }
}

void FileOps::CleanChannelIcons()
{
  // Currently XBMC's addon lib doesn't provide a way to list files in a directory.
  // Therefore we currently can't clean only leftover files.

  XBMC->Log(LOG_DEBUG, "%s: Cleaning channel icons %s", __FUNCTION__, m_localBasePath.c_str());

  CLockObject lock(m_lock);

  // Remove cache sub directories
  std::vector<FileType>::const_iterator it;
  std::vector<FileType> fileTypes = GetFileTypes();
  std::vector<std::string> directories;
  for (it = fileTypes.begin(); it != fileTypes.end(); ++it)
  {
    if (*it == FileTypeChannelIcon)
    {
      std::string directory(GetTypeNameByFileType(*it));
      if (!directory.empty())
        directories.push_back(m_localBasePath + directory);
    }
  }
  std::vector<std::string>::const_iterator it2;
  for (it2 = directories.begin(); it2 != directories.end(); ++it2)
  {
    if (XBMC->DirectoryExists(it2->c_str()) && !XBMC->RemoveDirectory(it2->c_str()))
    {
      XBMC->Log(LOG_ERROR, "%s: Failed to remove cache sub directory %s", __FUNCTION__, it2->c_str());
    }
  }

  // Clear the cached local filenames so that new cache jobs get generated
  m_icons.clear();
}

void *FileOps::Process()
{
  XBMC->Log(LOG_DEBUG, "%s: FileOps Thread Started", __FUNCTION__);

  std::list<FileOps::JobItem> jobQueueDelayed;

  while (!IsStopped())
  {
    // Wake this thread from time to time to clean the cache and recache empty files (delayed queue)
    // For caching new files, the tread is woken up by m_queueContent.Signal();
    m_queueContent.Wait(c_timeoutProcess * 1000);

    if (m_jobQueue.empty() && !IsStopped())
    {
      if (m_localBaseStamp != FILEOPS_NOSTAMP && difftime(time(NULL), m_localBaseStamp) >= c_cacheMaxAge)
      {
        CleanCache();
        if (m_consumer)
          m_consumer->HandleCleanedCache();
      }
    }

    while (!m_jobQueue.empty() && !IsStopped())
    {
      CLockObject lock(m_lock);
      FileOps::JobItem job = m_jobQueue.front();
      m_jobQueue.pop_front();
      lock.Unlock();

      if (g_bExtraDebug)
        XBMC->Log(LOG_DEBUG,"%s: Job fetched: type: %d, local: %s", __FUNCTION__, job.m_fileType, job.m_localFilename.c_str());
      // Try to open the destination file
      void *file = OpenFile(job.m_localFilename.c_str());
      if (!file)
        continue;

      // Connect to the stream
      Myth::WSStreamPtr fileStream;
      switch (job.m_fileType)
      {
      case FileTypeThumbnail:
        fileStream = m_wsapi->GetPreviewImage(job.m_recording.ChannelID(), job.m_recording.RecordingStartTime());
        break;
      case FileTypeChannelIcon:
        fileStream = m_wsapi->GetChannelIcon(job.m_channel.ID());
        break;
      case FileTypeCoverart:
      case FileTypeFanart:
        fileStream = m_wsapi->GetRecordingArtwork(GetTypeNameByFileType(job.m_fileType), job.m_recording.Inetref(), job.m_recording.Season());
        break;
      default:
        break;
      }

      if (fileStream && fileStream->GetSize() > 0)
      {
        // Cache it to the local addon cache
        bool cached = CacheFile(file, fileStream.get());
        XBMC->CloseFile(file);

        if (cached)
        {
          if (g_bExtraDebug)
            XBMC->Log(LOG_DEBUG, "%s: File Cached: type: %d, local: %s", __FUNCTION__, job.m_fileType, job.m_localFilename.c_str());
        }
        else
        {
          XBMC->Log(LOG_DEBUG, "%s: Caching file failed: type: %d, local: %s", __FUNCTION__, job.m_fileType, job.m_localFilename.c_str());
          if (XBMC->FileExists(job.m_localFilename.c_str(), true))
            XBMC->DeleteFile(job.m_localFilename.c_str());
        }
      }
      else
      {
        XBMC->CloseFile(file);

        // Failed to open file for reading. Unfortunately it cannot be determined if this is a permanent or a temporary problem (new recording's preview hasn't been generated yet).
        // Increase the error count and retry to cache the file a few times
        if (!fileStream)
        {
          XBMC->Log(LOG_ERROR, "%s: Failed to read file: type: %d, local: %s", __FUNCTION__, job.m_fileType, job.m_localFilename.c_str());
          job.m_errorCount += 1;
        }

        // File was empty (this happens usually for new recordings where the preview image hasn't been generated yet)
        // This is not an error, always try to recache the file
        else if (fileStream->GetSize() <= 0)
        {
          XBMC->Log(LOG_DEBUG, "%s: File is empty: type: %d, local: %s", __FUNCTION__, job.m_fileType, job.m_localFilename.c_str());
        }

        // Recache the file if it hasn't exceeded the maximum number of allowed attempts
        if (job.m_errorCount <= c_maximumAttemptsOnReadError)
        {
          XBMC->Log(LOG_DEBUG, "%s: Delayed recache file: type: %d, local: %s", __FUNCTION__, job.m_fileType, job.m_localFilename.c_str());
          jobQueueDelayed.push_back(job);
        }
      }
    }

    // Try to recache the currently empty files
    CLockObject lock(m_lock);
    m_jobQueue.insert(m_jobQueue.end(), jobQueueDelayed.begin(), jobQueueDelayed.end());
    jobQueueDelayed.clear();
  }

  XBMC->Log(LOG_DEBUG, "%s: FileOps Thread Stopped", __FUNCTION__);
  return NULL;
}

bool FileOps::CheckFile(const std::string& localFilename)
{
  bool ret = false;
  if (XBMC->FileExists(localFilename.c_str(), true))
  {
    void *file = XBMC->OpenFile(localFilename.c_str(), 0);
    if (XBMC->GetFileLength(file) > 0)
      ret = true;
    XBMC->CloseFile(file);
  }
  return ret;
}

void *FileOps::OpenFile(const std::string& localFilename)
{
  // Try to open the file. If it fails, check if we need to create the directory first.
  // This way we avoid checking if the directory exists every time.
  void *file;
  if (!(file = XBMC->OpenFileForWrite(localFilename.c_str(), true)))
  {
    std::string cacheDirectory = GetDirectoryName(localFilename);
    if (XBMC->DirectoryExists(cacheDirectory.c_str()) || XBMC->CreateDirectory(cacheDirectory.c_str()))
    {
      if (g_bExtraDebug)
        XBMC->Log(LOG_DEBUG, "%s: Created cache directory: %s", __FUNCTION__, cacheDirectory.c_str());

      if (!(file = XBMC->OpenFileForWrite(localFilename.c_str(), true)))
      {
        XBMC->Log(LOG_ERROR, "%s: Failed to create cache file: %s", __FUNCTION__, localFilename.c_str());
        return NULL;
      }
    }
    else
    {
      XBMC->Log(LOG_ERROR, "%s: Failed to create cache directory: %s", __FUNCTION__, cacheDirectory.c_str());
      return NULL;
    }
  }
  return file;
}

bool FileOps::CacheFile(void *file, Myth::Stream *source)
{
  int64_t size = source->GetSize();
  char *buffer = new char[FILEOPS_STREAM_BUFFER_SIZE];

  while (size > 0)
  {
    int br = source->Read(buffer, (size > FILEOPS_STREAM_BUFFER_SIZE ? FILEOPS_STREAM_BUFFER_SIZE : (unsigned)size));
    if (br <= 0)
      break;
    size -= br;
    char *p = buffer;
    while (br > 0)
    {
      int bw = XBMC->WriteFile(file, p, br);
      if (bw <= 0)
        break;

      br -= bw;
      p += bw;
    }
  }
  delete[] buffer;

  if (size)
    XBMC->Log(LOG_NOTICE, "%s: Did not consume everything (%ld)", __FUNCTION__, (long)size);
  return true;
}

static void WriteCacheStamp(const char *path, time_t ts)
{
  void * hdl = XBMC->OpenFileForWrite(path, true);
  if (hdl == NULL)
  {
    XBMC->Log(LOG_ERROR,"%s: Write stamp file %s failed", __FUNCTION__, path);
    return;
  }
  std::string now(Myth::TimeToString(ts, true));
  XBMC->WriteFile(hdl, now.c_str(), now.length());
  XBMC->CloseFile(hdl);
}

static time_t ReadCacheStamp(const char *path)
{
  time_t ts = FILEOPS_NOSTAMP;
  char buf[21]; // Time string as ISO-8601/UTC: %y-%m-%d"T"%H:%M:%S"Z"
  memset(buf, 0, sizeof(buf));
  void * hdl = XBMC->OpenFile(path, 0);
  if (hdl == NULL)
  {
    XBMC->Log(LOG_ERROR,"%s: Read stamp file %s failed", __FUNCTION__, path);
    // Try write a new one
    ts = time(NULL);
    WriteCacheStamp(path, ts);
    return ts;
  }
  if (XBMC->ReadFile(hdl, (void*)buf, (int64_t)(sizeof(buf) - 1)))
    ts = Myth::StringToTime(buf); // It returns FILEOPS_NOSTAMP for invalid buf
  XBMC->CloseFile(hdl);
  // If stamp is invalid we overwrite it
  if (ts == FILEOPS_NOSTAMP)
  {
    XBMC->Log(LOG_ERROR,"%s: Bad stamp string '%s'", __FUNCTION__, buf);
    ts = time(NULL);
    WriteCacheStamp(path, ts);
  }
  return ts;
}

void FileOps::InitBasePath()
{
  XBMC->Log(LOG_DEBUG, "%s: Configure cache directory %s", __FUNCTION__, m_localBasePath.c_str());

  CLockObject lock(m_lock);

  // Create the cache directories if it does not exist
  if (!XBMC->DirectoryExists(m_localBasePath.c_str()) && !XBMC->CreateDirectory(m_localBasePath.c_str()))
  {
    XBMC->Log(LOG_ERROR,"%s: Failed to create cache directory %s", __FUNCTION__, m_localBasePath.c_str());
    return;
  }
  if (!XBMC->FileExists(m_localBaseStampName.c_str(), false))
  {
    m_localBaseStamp = time(NULL);
    WriteCacheStamp(m_localBaseStampName.c_str(), m_localBaseStamp);
    return;
  }
  m_localBaseStamp = ReadCacheStamp(m_localBaseStampName.c_str());
  XBMC->Log(LOG_DEBUG,"%s: Cache stamp is %s", __FUNCTION__, ctime(&m_localBaseStamp));
  if (difftime(time(NULL), m_localBaseStamp) >= c_cacheMaxAge)
    CleanCache();
}

void FileOps::CleanCache()
{
  // Currently XBMC's addon lib doesn't provide a way to list files in a directory.
  // Therefore we currently can't clean only leftover files.

  XBMC->Log(LOG_DEBUG, "%s: Cleaning cache %s", __FUNCTION__, m_localBasePath.c_str());

  CLockObject lock(m_lock);

  // Remove cache sub directories
  std::vector<FileType>::const_iterator it;
  std::vector<FileType> fileTypes = GetFileTypes();
  std::vector<std::string> directories;
  for (it = fileTypes.begin(); it != fileTypes.end(); ++it)
  {
    std::string directory(GetTypeNameByFileType(*it));
    if (!directory.empty() && *it != FileTypeChannelIcon)
      directories.push_back(m_localBasePath + directory);
  }
  std::vector<std::string>::const_iterator it2;
  for (it2 = directories.begin(); it2 != directories.end(); ++it2)
  {
    if (XBMC->DirectoryExists(it2->c_str()) && !XBMC->RemoveDirectory(it2->c_str()))
    {
      XBMC->Log(LOG_ERROR,"%s: Failed to remove cache sub directory %s", __FUNCTION__, it2->c_str());
    }
  }

  // Clear the cached local filenames so that new cache jobs get generated
  m_preview.clear();
  m_artworks.clear();

  // Reset stamp file
  m_localBaseStamp = time(NULL);
  WriteCacheStamp(m_localBaseStampName.c_str(), m_localBaseStamp);
  XBMC->Log(LOG_DEBUG, "%s: New cache stamp is %s", __FUNCTION__, ctime(&m_localBaseStamp));
}

std::string FileOps::GetFileName(const std::string& path, char separator)
{
  size_t pos = path.find_last_of(separator);
  return path.substr(pos + 1);
}

std::string FileOps::GetDirectoryName(const std::string& path, char separator)
{
  size_t pos = path.find_last_of(separator);
  return path.substr(0, pos);
}
