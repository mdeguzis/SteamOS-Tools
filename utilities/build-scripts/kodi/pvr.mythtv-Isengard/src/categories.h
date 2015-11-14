#pragma once
/*
 *      Copyright (C) 2005-2012 Team XBMC
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

#include <string>
#include <map>

typedef std::multimap<int, std::string> CategoryByIdMap;
typedef std::map<std::string, int> CategoryByNameMap;

class Categories
{
public:
  Categories();

  std::string Category(int category) const;
  int Category(const std::string& category) const;

private:
  void LoadEITCategories(const char *filePath);

  CategoryByIdMap   m_categoriesById;
  CategoryByNameMap m_categoriesByName;
};
