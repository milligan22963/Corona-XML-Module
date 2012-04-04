module(..., package.seeall)

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--
-- xml.lua - XML parser for use with the Corona SDK.
--
-- version: 1.1
--
-- CHANGELOG:
--
-- 1.1 - Fixed base directory issue with the loadFile() function.
--
-- NOTE: This is a modified version of Alexander Makeev's Lua-only XML parser
-- found here: http://lua-users.org/wiki/LuaXml
--
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------

function newParser()

	XmlParser = {};
	
	function XmlParser:ToXmlString(value)
		value = string.gsub (value, "&", "&amp;");		-- '&' -> "&amp;"
		value = string.gsub (value, "<", "&lt;");		-- '<' -> "&lt;"
		value = string.gsub (value, ">", "&gt;");		-- '>' -> "&gt;"
		value = string.gsub (value, "\"", "&quot;");	-- '"' -> "&quot;"
		value = string.gsub(value, "([^%w%&%;%p%\t% ])",
			function (c) 
				return string.format("&#x%X;", string.byte(c)) 
			end);
		return value;
	end
	
	function XmlParser:FromXmlString(value)
		value = string.gsub(value, "&#x([%x]+)%;",
			function(h) 
				return string.char(tonumber(h,16)) 
			end);
		value = string.gsub(value, "&#([0-9]+)%;",
			function(h) 
				return string.char(tonumber(h,10)) 
			end);
		value = string.gsub (value, "&quot;", "\"");
		value = string.gsub (value, "&apos;", "'");
		value = string.gsub (value, "&gt;", ">");
		value = string.gsub (value, "&lt;", "<");
		value = string.gsub (value, "&amp;", "&");
		return value;
	end
	   
	function XmlParser:ParseArgs(s)
	  local arg = {}
	  string.gsub(s, "(%w+)=([\"'])(.-)%2", function (w, _, a)
			arg[w] = self:FromXmlString(a);
		end)
	  return arg
	end
	
	function XmlParser:ParseXmlText(xmlText)
	  local stack = {}
	  local namespace = {}
	  local labelNamespace = nil
	  local top = {name=nil,value=nil,properties={},child={}, namespace=nil}
	  table.insert(stack, top)
	  local ni,c,label,xarg, empty
	  local i, j = 1, 1
	  local namespaceIndex = 1
	  while true do
		ni,j,c,label,xarg, empty = string.find(xmlText, "<(%/?)([%w:]+)(.-)(%/?)>", i)
		if not ni then break end
		local text = string.sub(xmlText, i, ni-1);
		if not string.find(text, "^%s*$") then
		  top.value=(top.value or "")..self:FromXmlString(text);
		end
		namespaceIndex = 1
		while true do
		  	namespaceIndex = string.find(xarg, "xmlns:", namespaceIndex)
			if not namespaceIndex then break end
			local equalSign = string.find(xarg, "=", namespaceIndex)
			local nsName = string.sub(xarg, namespaceIndex + 6, equalSign -1)
			local endNS = string.find(xarg, "\" ", equalSign + 2)
			namespace[nsName] = string.sub(xarg, equalSign + 1, endNS + 1)
			-- print("Name space: " .. nsName .. ":" ..namespace[nsName])
			namespaceIndex = equalSign
		end
		-- ditch name space
		if label then
			local matchcount = 0
			-- walk through our namespace table nuking it as we go
			for k in pairs(namespace) do
				label, matchcount = string.gsub(label, k..":", "");
				if matchcount >= 1 then
					labelNamespace = k
				else
					labelNamespace = nil
				end
			end
		end
		if empty == "/" then  -- empty element tag
		  table.insert(top.child, {name=label,value=nil,properties=self:ParseArgs(xarg),child={}})
		elseif c == "" then   -- start tag
		  top = {name=label, value=nil, properties=self:ParseArgs(xarg), child={}, namespace=labelNamespace}
		  table.insert(stack, top)   -- new level
		else  -- end tag
		  local toclose = table.remove(stack)  -- remove top
		  top = stack[#stack]
		  if #stack < 1 then
			error("XmlParser: nothing to close with "..label)
		  end
		  if toclose.name ~= label then
			error("XmlParser: trying to close "..toclose.name.." with "..label)
		  end
		  table.insert(top.child, toclose)
		end
		i = j+1
	  end
	  local text = string.sub(xmlText, i);
	  if not string.find(text, "^%s*$") then
		  stack[#stack].value=(stack[#stack].value or "")..self:FromXmlString(text);
	  end
	  if #stack > 1 then
		error("XmlParser: unclosed "..stack[stack.n].name)
	  end
	  stack[1].child[1].namespace = namespace
	  return stack[1].child[1];
	end
	
	function XmlParser:loadFile(xmlFilename, base)
		if not base then
			base = system.ResourceDirectory
		end
			
		local path = system.pathForFile( xmlFilename, base )
		local hFile, err = io.open(path,"r");
		
		if hFile and not err then
			local xmlText=hFile:read("*a"); -- read file content
			io.close(hFile);
			return self:ParseXmlText(xmlText),nil;
		else
			print( err )
			return nil
		end
	end
	
	return XmlParser
end
