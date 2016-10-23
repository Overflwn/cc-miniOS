--[[

				miniOS

	As the name already says, this OS is not
	a real "OS", like you'd expect it to be.

	I think you can call it a window manager

	~Piorjade
]]--

--[[
			Variables
		(and minimal thread API)			
]]
tasks = {}
windows = {}
selected = ""

--define the thread api
local thread = {}

function thread.new(path)
	if not fs.exists(path) or fs.isDir(path) then
		return nil
	end
	local self = {}
	--load the file as function
	self.func, err = loadfile(path)
	if not self.func then
		return false, err
	end
	--create a new enviroment for the file and put it in there
	self.env = {}
	setmetatable(self.env, {})
	local function _copy(a, b)
		for k, v in pairs(a) do
			b[k] = v
		end
	end
	_copy(_G, self.env)
	setfenv(self.func, self.env)
	--defines variables
	if not tasks[path] then
		self.path = path
	else
		local kek = path
		local nkek = kek
		local counter = 1
		repeat
			nkek = kek..tostring(counter)
			counter = counter+1
		until not tasks[nkek]
		self.path = nkek
	end
	self.task = coroutine.create(self.func)
	self.dead = false
	self.paused = false
	self.filter = nil
	self.invisible = false
	--define resume function (--> runs the file)
	function self.resume(...)
		local fst = {...}
		if self.filter == nil and not self.paused or fst[1] == self.filter and not self.paused then
			local ok, err = coroutine.resume(self.task, unpack(fst))
			if ok then
				local stat = coroutine.status(self.task)
				if stat == "dead" then
					self.dead = true
				else
					self.filter = err
				end
			else
				self.dead = true
				printError(err)
			end
		end
	end
	tasks[self.path] = self
	--create a new window for the file
	--xA/yA = top left corner, xO/yO = bottom right corner
	local maxX, maxY = term.getSize()
	windows[self.path] = {}
	windows[self.path]['xA'] = 1
	windows[self.path]['yA'] = 1
	windows[self.path]['xO'] = maxX
	windows[self.path]['yO'] = maxY
	windows[self.path]['w'] = window.create(oldTerm, 1, 1, maxX, maxY)
	windows[self.path]['w'].setBackgroundColor(colors.gray)
	windows[self.path]['w'].setTextColor(colors.black)
	windows[self.path]['w'].clear()
	windows[self.path]['w'].setTextColor(colors.red)
	windows[self.path]['w'].setCursorPos(maxX, 1)
	windows[self.path]['w'].write("O")
	windows[self.path]['w'].setTextColor(colors.yellow)
	windows[self.path]['w'].setCursorPos(maxX-1, 1)
	windows[self.path]['w'].write("O")
	windows[self.path]['w'].setTextColor(colors.green)
	windows[self.path]['w'].setCursorPos(maxX-2, 1)
	windows[self.path]['w'].write("O")
	windows[self.path]['uw'] = window.create(windows[self.path]['w'], 2, 2, maxX-2, maxY-2)
	if #selected > 0 then
		--windows[selected]['w'].setVisible(false)
	end
	selected = self.path
	return true
end

--[[
		functions
]]
local function clear(bg, fg)
	term.setCursorPos(1,1)
	term.setBackgroundColor(bg)
	term.setTextColor(fg)
	term.clear()
end

local function redrawWindows()
	
	for each, task in pairs(tasks) do
		if not task.dead and not task.invisible then
			windows[task.path]['w'].redraw()
			windows[task.path]['uw'].redraw()
		end
	end
	if #selected > 0 and not tasks[selected].invisible then
		windows[selected]['w'].redraw()
		windows[selected]['uw'].redraw()
	end
end

local function drawSys()
	clear(colors.lightBlue, colors.black)
	local textBox = window.create(oldTerm, 1, 1, 20, 1, false)
	textBox.setBackgroundColor(colors.gray)
	textBox.setTextColor(colors.lime)
	textBox.clear()
	local evt = {}
	
	--start loop
	while true do
		
		evt = {os.pullEventRaw()}
		local event, button, x, y = unpack(evt)

		if event == "key" and button == keys.f1 then
			textBox.setVisible(true)
			term.redirect(textBox)
			clear(colors.gray, colors.lime)
			term.write("Path: ")
			local oprint = _G.print
			_G.print = function(t)
				return term.write(t)
			end
			local e = read()
			_G.print = oprint
			term.redirect(oldTerm)
			textBox.setVisible(false)
			clear(colors.lightBlue, colors.black)
			thread.new(e)
		elseif event == "mouse_click" then
			if button == 1 then
				if #selected > 0 and x == windows[selected]['xO'] and y == windows[selected]['yA'] then
					--close a window
					tasks[selected].dead = true
					--table.insert(queueRemove, selected)
					tasks[selected] = nil
					windows[selected] = nil
					selected = ""
					clear(colors.lightBlue, colors.black)
					redrawWindows()
				elseif #selected > 0 and x == windows[selected]['xO']-1 and y == windows[selected]['yA'] then
					--maximize a window
					local maxX, maxY = term.getSize()
					windows[selected]['w'].reposition(1, 1, maxX, maxY)
					windows[selected]['uw'].reposition(2, 2, maxX-2, maxY-2)
					windows[selected]['xA'] = 1
					windows[selected]['yA'] = 1
					windows[selected]['xO'] = maxX
					windows[selected]['yO'] = maxY
					windows[selected]['w'].setBackgroundColor(colors.gray)
					windows[selected]['w'].setTextColor(colors.black)
					windows[selected]['w'].clear()
					windows[selected]['w'].setTextColor(colors.red)
					windows[selected]['w'].setCursorPos(maxX, 1)
					windows[selected]['w'].write("O")
					windows[selected]['w'].setTextColor(colors.yellow)
					windows[selected]['w'].setCursorPos(maxX-1, 1)
					windows[selected]['w'].write("O")
					windows[selected]['w'].setTextColor(colors.green)
					windows[selected]['w'].setCursorPos(maxX-2, 1)
					windows[selected]['w'].write("O")
					clear(colors.lightBlue, colors.black)
					redrawWindows()
				elseif #selected > 0 and x == windows[selected]['xO']-2 and y == windows[selected]['yA'] then
					--minimize a window
					tasks[selected].invisible = true
					windows[selected]['w'].setVisible(false)
					selected = ""
					clear(colors.lightBlue, colors.black)
					redrawWindows()
				elseif #selected > 0 and x == windows[selected]['xO'] and y == windows[selected]['yO'] then
					--resize the window
					local nevt = {}
					local cx = x
					local cy = y
					local width, height = 1,1
					repeat
						nevt = {os.pullEvent()}
						if nevt[1] == "mouse_drag" and nevt[3] >= windows[selected]['xA']+2 and nevt[4] >= windows[selected]['yA']+2 then
							width = windows[selected]['xO']-windows[selected]['xA']+1
							height = windows[selected]['yO']-windows[selected]['yA']+1

							if width >= 3 and height >= 3 then
								windows[selected]['xO'] = nevt[3]
								windows[selected]['yO'] = nevt[4]
								local maxX = windows[selected]['xO']
								local maxY = windows[selected]['yO']
								width = windows[selected]['xO']-windows[selected]['xA']+1
								height = windows[selected]['yO']-windows[selected]['yA']+1
								windows[selected]['w'].reposition(windows[selected]['xA'], windows[selected]['yA'], width, height)
								windows[selected]['uw'].reposition(2, 2, width-2, height-2)
								windows[selected]['w'].setBackgroundColor(colors.gray)
								windows[selected]['w'].setTextColor(colors.black)
								windows[selected]['w'].clear()
								windows[selected]['w'].setTextColor(colors.red)
								windows[selected]['w'].setCursorPos(width, 1)
								windows[selected]['w'].write("O")
								windows[selected]['w'].setTextColor(colors.yellow)
								windows[selected]['w'].setCursorPos(width-1, 1)
								windows[selected]['w'].write("O")
								windows[selected]['w'].setTextColor(colors.green)
								windows[selected]['w'].setCursorPos(width-2, 1)
								windows[selected]['w'].write("O")
								clear(colors.lightBlue, colors.black)
								redrawWindows()
							end
						end
					until nevt[1] == "mouse_up"
					clear(colors.lightBlue, colors.black)
					redrawWindows()
				elseif #selected > 0 and x >= windows[selected]['xA'] and x <= windows[selected]['xO']-2 and y == windows[selected]['yA'] then
					--move the window
					local nevt = {}
					local abstand = x-windows[selected]['xA']
					local width, height = windows[selected]['w'].getSize()
					local cx = x
					local cy = y
					repeat
						nevt = {os.pullEvent()}
						
						if nevt[1] == "mouse_drag" then
							windows[selected]['xA'] = nevt[3]-abstand
							windows[selected]['yA'] = nevt[4]
							windows[selected]['xO'] = windows[selected]['xA']+width-1
							windows[selected]['yO'] = windows[selected]['yA']+height-1
							windows[selected]['w'].reposition(windows[selected]['xA'], windows[selected]['yA'], width, height)
							clear(colors.lightBlue, colors.black)
							redrawWindows()
						end
					until nevt[1] == "mouse_up"
					clear(colors.lightBlue, colors.black)
					redrawWindows()
				else
					if #selected > 0 then
						for each, window in pairs(windows) do
							if x < windows[selected]['xA'] or y > windows[selected]['yO'] or x > windows[selected]['xO'] or y < windows[selected]['yA'] then 
								if x >= window.xA and x <= window.xO and y >= window.yA and y <= window.yO then
									--windows[selected]['w'].setVisible(false)
									selected = each
									--windows[selected]['w'].setVisible(true)
									break
								end
							end
						end
					else
						for each, window in pairs(windows) do
							if x >= window.xA and x <= window.xO and y >= window.yA and y <= window.yO then
								selected = each
								--windows[selected]['w'].setVisible(true)
								break
							end
						end
					end
					clear(colors.lightBlue, colors.black)
					redrawWindows()
				end
			end
		end
	end
end
--[[
		code
]]
--catch the original terminal (for orientation)
oldTerm = term.current()
queueRemove = {}
--list every event that should only be passed to the selected window
ll = {
	"key",
	"char",
	"mouse_click",
	"mouse_down",
	"mouse_drag"
}
parallel.waitForAll(
	function()
		drawSys()
	end,
	function()
		local evt = {}
		while true do
			for task, a in pairs(tasks) do
				--resume all non-selected windows
				if not a.dead and not a.path == selected then
					local found = false
					--check if the current event is one of the listed. if yes, don't resume
					for _, a in ipairs(ll) do
						if evt[1] == a then
							found = true
							break
						else
							found = false
						end
					end
					if not found then
						term.redirect(windows[a.path]['uw'])
						a.resume(unpack(evt))
						term.redirect(oldTerm)
					end
				end
			end
			if tasks[selected] then
				if not tasks[selected].dead then
					if evt[1] == "mouse_click" or evt[1] == "mouse_up" or evt[1] == "mouse_down" or evt[1] == "mouse_drag" then
						if evt[3] > windows[selected]['xA'] and evt[3] < windows[selected]['xO'] and evt[4] > windows[selected]['yA'] and evt[4] < windows[selected]['yO'] then
							evt[3] = evt[3]-windows[selected]['xA']
							evt[4] = evt[4]-windows[selected]['yA']
							term.redirect(windows[selected]['uw'])
							tasks[selected].resume(unpack(evt))
							term.redirect(oldTerm)
						else
							term.redirect(windows[selected]['uw'])
							tasks[selected].resume({})
							term.redirect(oldTerm)
						end
					else
						term.redirect(windows[selected]['uw'])
						tasks[selected].resume(unpack(evt))
						term.redirect(oldTerm)
					end
				end
			end
			for each, entry in ipairs(queueRemove) do
				tasks[entry] = nil
				windows[entry] = nil
				table.remove(queueRemove, each)

			end
			evt = {os.pullEventRaw()}
		end
	end)