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

#include "mythcontrol.h"

using namespace Myth;

Control::Control(const std::string& server, unsigned protoPort, unsigned wsapiPort, const std::string& wsapiSecurityPin)
: m_monitor(server, protoPort)
, m_wsapi(server, wsapiPort, wsapiSecurityPin)
{
  Open();
}

Control::Control(const std::string& server, unsigned protoPort, unsigned wsapiPort, const std::string& wsapiSecurityPin, bool blockShutdown)
: m_monitor(server, protoPort, blockShutdown)
, m_wsapi(server, wsapiPort, wsapiSecurityPin)
{
  Open();
}

Control::~Control()
{
  Close();
}

bool Control::Open()
{
  if (m_monitor.IsOpen())
    return true;
  return m_monitor.Open();
}

void Control::Close()
{
  m_monitor.Close();
}

std::string Control::GetBackendServerIP(const std::string& hostName)
{
  std::string backend_addr;
  // Query backend server IP
  Myth::SettingPtr settingAddr = this->GetSetting("BackendServerIP", hostName);
  if (settingAddr && !settingAddr->value.empty())
    backend_addr = settingAddr->value;
  return backend_addr;
}

std::string Control::GetBackendServerIP6(const std::string& hostName)
{
  std::string backend_addr;
  // Query backend server IP6
  Myth::SettingPtr settingAddr = this->GetSetting("BackendServerIP6", hostName);
  if (settingAddr && !settingAddr->value.empty() && settingAddr->value != "::1")
    backend_addr = settingAddr->value;
  return backend_addr;
}

unsigned Control::GetBackendServerPort(const std::string& hostName)
{
  int backend_port;
  // Query backend server port
  Myth::SettingPtr settingPort = this->GetSetting("BackendServerPort", hostName);
  if (settingPort && !settingPort->value.empty() && (backend_port = Myth::StringToInt(settingPort->value)) > 0)
    return backend_port;
  return 0;
}

bool Control::RefreshRecordedArtwork(Program& program)
{
  program.artwork.clear();
  if (program.inetref.empty())
    return false;
  ArtworkListPtr artworks(GetRecordingArtworkList(program.channel.chanId, program.recording.startTs));
  program.artwork.reserve(artworks->size());
  for (ArtworkList::const_iterator it = artworks->begin(); it < artworks->end(); ++it)
  {
    program.artwork.push_back(*(it->get()));
  }
  return (program.artwork.empty() ? false : true);
}
