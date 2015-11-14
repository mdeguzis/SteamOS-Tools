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

#include "client.h"

#include <vector>
#include <map>

#define ACTION_KEY_EXIT       122
#define ACTION_KEY_BACK       92
#define ACTION_KEY_STOP       13

class GUIDialogBase
{
public:
  GUIDialogBase(const char *xmlFileName, const char *defaultSkin);
  virtual ~GUIDialogBase();

  virtual bool Open();
  virtual bool OnInit() = 0;
  virtual bool OnClick(int controlId);
  virtual bool OnFocus(int controlId);
  virtual bool OnAction(int actionId);

  static bool OnClickCB(GUIHANDLE cbhdl, int controlId);
  static bool OnFocusCB(GUIHANDLE cbhdl, int controlId);
  static bool OnInitCB(GUIHANDLE cbhdl);
  static bool OnActionCB(GUIHANDLE cbhdl, int actionId);

private:
  GUIDialogBase();
  std::string m_xmlFileName;
  std::string m_defaultSkin;

protected:
  void ClearListItems();

  CAddonGUIWindow *m_window;
  std::vector<CAddonListItem*> m_listItems;
  std::map<GUIHANDLE, int> m_listItemsMap;
};
