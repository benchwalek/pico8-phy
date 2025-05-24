pico-8 cartridge // http://www.pico-8.com
version 39
__lua__
bodies = {}
joints = {}
contacts = {}
timescale = 1
dt = timescale/60
paused = true
iter = 10
col,row = 6,5
n_bodies = 0

debug = false
debug_table={}

-- meters
scale=16

-- test gmask
-- large obj: gmask doesnt work
-- streamline scale handling
-- streamline collides
-- find more clear way to min/max
-- remove joint when rem body
-- do not collide if both obj static
-- cache sat axis
-- editing tools:
--		- change aim and lim sep
-- 	- arbitrary joints
--		- masses
-- sat: bias axis, margin

-- holy trifecta
function _init()
	assert(row * col <= 32)
	-- mouse
	poke(0x5f2d, 1)
	g = v2(0, -10/16*scale)
--	demo_scene()
end

pms = 0
rx, ry = 1/16*scale,1/16*scale
ap = 0
function _update60()
	debug_table = {}
	mx,my,ms = stat(32),stat(33),stat(34)
	
	-- lmb
	if pms&1==0 and ms&1==1 then
		if btn(🅾️) then
			add(bodies,
							body({lp=from_ss(mx,my),
													ap=ap,
													rx=rx,
													ry=ry,
													lim=0,
													aim=0}))
			bodies[#bodies].id = n_bodies
		else
			add(bodies,
							body({lp=from_ss(mx,my),
													ap=ap,
													rx=rx,
													ry=ry,
													lim=1,
													aim=1}))
			bodies[#bodies].id = n_bodies
		end
		n_bodies+=1
	end
	-- rmb
	if pms&2==0 and ms&2==2 then
		add(joints,
			ball_cns(from_ss(mx,my),
												bodies[#bodies],
												bodies[#bodies-1]))
	end
	
	pms = ms
	
	if btnp(❎) then
		paused = not paused
	end
	if not btn(🅾️) then
		if btn(⬆️) then
			ry += ry * 1 * dt
		end
		if btn(⬇️) then
			ry -= ry * 1 * dt
			ry = max(.25,ry)
		end
		if btn(➡️) then
			rx += rx * 1 * dt
		end
		if btn(⬅️) then
			rx -= rx * 1 * dt
			rx = max(.25,rx)
		end
	else
		if btn(⬅️) then
			ap += tau/4*dt
			ap %= tau
		end
		if btn(➡️) then
			ap -= tau/4*dt
			ap %= tau
		end
	end
	
	-- calculate mask
	for b in all(bodies) do
		b.gmask = gmask(b)
	end
	
	-- del offscreen bodies/joints
	for i,b in ipairs(bodies) do
		if mid(b.lp[1],0,scale) ~= b.lp[1]
		or mid(b.lp[2],0,scale) ~= b.lp[2] then
			deli(bodies, i)
			for k,j in ipairs(joints) do
				if j.a == b or j.b == b then
					deli(joints,k)
				end
			end
		end
	end
	
	debug_table.cworst = 0
	debug_table.cact = 0
	debug_table.cbest = 0
	contacts = {}
	
--	bef = stat(1)
	for i=1,#bodies do
		for j=i+1,#bodies do
			debug_table.cworst += 1
			local a, b = bodies[i], bodies[j]
			if a ~= b -- not self
			-- not both static
			and a.lim + a.aim
					+ b.lim + b.aim > 0
			-- broad phse
			and a.gmask & b.gmask ~= 0 then
				-- [check cached axis]
				local c = sat(a,b)
				debug_table.cact += 1

				if c ~= nil then
					debug_table.cbest += 1
					for p in all(c.pts) do
						add(contacts,
										cont_cns(p[1], p[2], c.n, c.a, c.b))
					end
					
					if debug then
						local anc = c.pts[1][1]
						if (c.pts[2]) anc = s(.5)*(anc + c.pts[2][1])
						add(debug_table, {c.n,ty='vector',anchor=anc})
						for p in all(c.pts) do
							add(debug_table, {p[1],ty='point'})
							add(debug_table, {p[2],ty='point'})
						end
					end
				end
			end
		end
	end
	
	debug_table.joints = #joints
	debug_table.contacts = #contacts
	
	if (not paused) phystep(dt)
end

function _draw()
	cls()
	local bef = stat(1)
	grid()
	
	-- 16 bit binary string repr
	function bstr(x) 
		local s = ""
		for i=1,16 do
			s = s .. (x&1==1 and "1" or "0")
			x >>= 1
		end
		return s
	end

	for b in all(bodies) do
		-- objects are rectangles
		hull(b,7)
	end
	
	
	if debug then
		for c in all(joints) do
			if c.ty == "ball" then
				-- constraint handles
				local x,y=to_ss(c.a.lp+rot(c.ra,c.a.ap))
				line(6)
				line(to_ss(c.a.lp))
				line(x,y)
				pset(x,y,10)
				x,y=to_ss(c.b.lp+(rot(c.rb, c.b.ap)))
				line(6)
				line(to_ss(c.b.lp))
				line(x,y)
			 pset(x,y,11)
			end
		end
	end
	-- mouse cursor
	hull(body({lp=from_ss(mx,my),
												ap=ap,
												rx=rx,
												ry=ry}),6)
	pset(mx,my,6)

	-- debug table
	if debug then
		for i,f in pairs(debug_table) do
			if type(f) == "table" then
				if f.ty == 'point' then
					color(8)
					circ(to_ss(f[1]))
				elseif f.ty == 'vector' then
					line(3)
					line(to_ss(f.anchor))
					line(to_ss(f.anchor+f[1]*s(scale/16)))
				end
			else
				print(i .. ": " .. f, 7)
			end
		end
	end
end

function hull(body,c)
	local vert = hull_vert(body)
	line(c)
	for _,v in ipairs(vert) do
		line(to_ss(v))
	end
	line(to_ss(vert[1]))
	-- midpoint
	color(12)
	pset(to_ss(body.lp))
end

function grid()
	local cw,ch = 128/col,128/row
	for y=ch,128,ch do
		line(0,y,127,y,1)
	end
	for x=cw,128,cw do
		line(x,0,x,127,1)
	end
end

function demo_scene()
	function add_stack(x, y, n)
		local stack = {}
		for i=1,n do
			add(bodies, body(v2(x,y+2*i),0, 1, 1, i==1 and 0 or 1))
			bodies[#bodies].id = n_bodies
			n_bodies+=1
		end
	end

	add_stack(2, 2, 1)
	add_stack(4, 2, 2)
	add_stack(6, 2, 3)
	add_stack(8, 2, 4)
	add_stack(10, 2, 3)
	add_stack(12, 2, 2)
	add_stack(14, 2, 1)

end

function get_ccache(a,b)
	if (a.id > b.id) a,b = b,a
	return contact_cache[a.id+b.id*(b.id+1)/2]
end

function set_ccache(a,b,c)
		if (a.id > b.id) a,b = b,a
		contact_cache[a.id+b.id*(b.id+1)/2] = c
end
-->8
-- math/helpers
tau = 2*3.14159265358979
v2_meta = {
	__add = function (a, b)
		return v2(a[1]+b[1],
												a[2]+b[2])
	end,
	__sub = function (a, b)
		return v2(a[1]-b[1],
												a[2]-b[2])
	end,
	__mul = function (a, b)
		return v2(a[1]*b[1],
												a[2]*b[2])
	end,
	__unm = function(a)
		return v2(-a[1], -a[2])
	end
}


function s(s)
	return v2(s,s)
end
function v2(a,b)
	local v = {a,b}
	setmetatable(v, v2_meta)
	return v
end

function dot(a,b)
	return a[1]*b[1]+a[2]*b[2]
end

function rot(v, t)
	t /= tau
	local s,c = -sin(t),cos(t)
	return v2(v[1]*c-v[2]*s,
											v[1]*s+v[2]*c)
end

-- screen space transforms
function from_ss(x, y)
	return v2(x/128*scale, scale-y/128*scale)
end
function to_ss(p)
	return p[1]*128/scale, 128-p[2]*128/scale
end

function rect_vert(p,angle,rx,ry)
	if (ry == nil) ry = rx
	return {p+rot(v2(-rx,-ry),angle),
									p+rot(v2( rx,-ry),angle),
									p+rot(v2( rx, ry),angle),
									p+rot(v2(-rx, ry),angle)}
end

function hull_vert(body)
	if body.ty == 'rect' then
		return rect_vert(body.lp,
																			body.ap,
																			body.rx,
																			body.ry)
	end
end
																			
-->8
-- physics

body_template = {ty='rect',
																	lp=v2(0,0),
																	lv=v2(0,0),
																	lim=1,
																	ap=0,
																	av=0,
																	aim=1,
																	gmask=0,
																	rx=1,
																	ry=1}

function phystep(dt)
	-- apply external, update vel
	for b in all(bodies) do
		-- apply forces ?
		
	 -- semi-implicit euler
	 if b.lim > 0 then
	 	-- gravity
	 	b.lv = b.lv + g * s(dt)
	 end
	 
	 -- dampen
--	 b.av *= .99
--	 b.lv *= s(.99)
	end
	
	-- apply joint constraints
	for c in all(joints) do
		if c.ty == "ball" then
			ball_step(c)
		end
	end
	
	-- apply contact constraints
	for c in all(contacts) do
		contact_step(c)
		friction_step(c)
	end
	
	-- update positions
	for b in all(bodies) do
	 b.ap += b.av * dt
		b.lp += b.lv * s(dt)
	end
end

function ball_step(c)
		local ba, bb = c.a,c.b
		-- rotated handles
		local pa, pb = rot(c.ra, ba.ap),
																 rot(c.rb, bb.ap)
		-- skew matrices
		local ka, kb = v2(pa[2],-pa[1]),
																 v2(pb[2],-pb[1])
		-- perform internal iterations
		for i=1,iter do
			-- guP (=c')
			local dv = ba.lv - ka*s(ba.av)
												- bb.lv + kb*s(bb.av)
			-- c
			local cons = ba.lp + pa 
      								- bb.lp - pb
      
			-- s, simplified by hand
			local s11 = ba.lim + bb.lim
													+ ba.aim * pa[2]*pa[2]
													+ bb.aim * pb[2]*pb[2]
													
			local s12 = 0
													- ba.aim * pa[1]*pa[2]
													- bb.aim * pb[1]*pb[2]
			local s21 = s12
			local s22 = ba.lim + bb.lim
													+ ba.aim * pa[1]*pa[1]
													+ bb.aim * pb[1]*pb[1]
			
			-- imp = inv(s)*(-Bc/DT-guP)
			local beta = .1
			local ti = -cons*s(beta/dt)-dv
--				local ti = -dv
			local denom = (s11*s22-s12*s21)
			local imp = v2((s22*ti[1]-s12*ti[2])/denom,
																	(-s21*ti[1]+s11*ti[2])/denom)
			
			-- update velocities
			ba.lv += s(ba.lim)*imp
			bb.lv -= s(bb.lim)*imp
			ba.av -= ba.aim*dot(ka, imp)
			bb.av += bb.aim*dot(kb, imp)
		end
end

slop = .01
function contact_step(c)
	c.applied_imp = 0
	local ba, bb = c.a,c.b
	
	-- normal is on b, but given on a
	c.n = -c.n	
	-- rotated handles
	local pa, pb = rot(c.ra, ba.ap),
															 rot(c.rb, bb.ap)
	-- skew matrices
	local ka, kb = v2(pa[2],-pa[1]),
															 v2(pb[2],-pb[1])
	-- perform internal iterations
	for i=1,iter do
		-- guP (=c')
		local dv = dot(c.n,ba.lv - ka*s(ba.av)
																			- bb.lv + kb*s(bb.av))
		-- c
		local cons = 
			min(dot(c.n,ba.lp + pa 
     								- bb.lp - pb)+slop,0)
		-- s, simplified by hand
		local ss = ba.lim + bb.lim
											+ dot(c.n, ka+kb)*dot(c.n,ka+kb)
		
		local beta = .2
		local ti = -cons*beta/dt-dv

		local imp = ti / ss
--		imp *= 1+3*i/iter
		
		local tmp = c.applied_imp
		c.applied_imp = max(c.applied_imp+imp,0)
		imp = c.applied_imp - tmp
		
		
		-- update velocities
		ba.lv += s(ba.lim*imp)*c.n
		bb.lv -= s(bb.lim*imp)*c.n
		ba.av -= ba.aim*imp*dot(ka, c.n)
		bb.av += bb.aim*imp*dot(kb, c.n)
	end
end

function friction_step(c)
	c.friction_imp = 0
	local ba, bb = c.a,c.b
	
	-- normal is on b, but given on a
	c.n = -c.n	
	-- rotated handles
	local pa, pb = rot(c.ra, ba.ap),
															 rot(c.rb, bb.ap)
	-- skew matrices
	local ka, kb = v2(pa[2],-pa[1]),
															 v2(pb[2],-pb[1])
	-- perform internal iterations
	for i=1,10 do
		-- guP (=c')
		local t = v2(c.n[2], -c.n[1])
		local dv = dot(t,ba.lv - ka*s(ba.av)
																	- bb.lv + kb*s(bb.av))
																		
		
		-- s, simplified by hand
		local ss = ba.lim + bb.lim
											+ dot(t, ka+kb)*dot(t,ka+kb)
		local ti = -dv
		local imp = ti / ss
		
		local mu = .2

		local tmp = c.friction_imp
		c.friction_imp += imp
		c.friction_imp = mid(c.friction_imp, -mu*c.applied_imp, mu*c.applied_imp)
		imp = c.friction_imp - tmp
		
		-- update velocities
		ba.lv += s(ba.lim*imp)*t
		bb.lv -= s(bb.lim*imp)*t
		ba.av -= ba.aim*imp*dot(ka, t)
		bb.av += bb.aim*imp*dot(kb, t)
	end
end

function body(table)
	local body = {}
	for k,v in pairs(body_template) do 
		body[k] = v
	end
	for k,v in pairs(table) do 
		body[k] = v
	end
	return body
end


function ball_cns(wp,a,b)
	return	{ty="ball",
									a=a,
									b=b,
									ra=rot(wp-a.lp,-a.ap),
									rb=rot(wp-b.lp,-b.ap)}
end

function cont_cns(p1,p2,n,a,b)
	return	{a=a,
									b=b,
									ra=rot(p1-a.lp,-a.ap),
									rb=rot(p2-b.lp,-b.ap),
									n=n}
end
-->8
-- contacts
local cw,ch = scale/col,scale/row


function gmask(body)
	-- for x=1..col, y=1..row
	-- row*col <= 32
	function mask_bit(x,y)
		if mid(0,col,x)~=x
		or mid(0,row,y)~=y then
			return 0
		end
		return (1>>16)<<(x+col*y)
	end
	
	local xmin,xmax,ymin,ymax
			= 0x7fff,0x8000,0x7fff,0x8000
	local vert = hull_vert(body)
	local mask = 0
	for i=1,#vert do
		local x,y=flr(vert[i][1])\cw,
												flr(vert[i][2])\ch
		xmin = min(xmin, x)
		xmax = max(xmax, x)
		ymin = min(ymin, y)
		ymax = max(ymax, y)
	end
	
	for x=xmin,xmax do
		for y=ymin,ymax do
			mask |= mask_bit(x,y)
		end
	end

	return mask
end

function sat(a, b)
	-- clips a line l  with a clip
	-- boundary c
	function lclip(c,l)
		local dot = dot
		local t = -dot(c.n,l.p-c.p)/
													dot(c.n,l.q-l.p)
		
		local dp, dq = dot(c.n,l.p)-c.d,
																	dot(c.n,l.q)-c.d

		if dp > 0 and dq > 0 then
			l.p = s(t)*l.q+s(1-t)*l.p
			l.q = s(t)*l.q+s(1-t)*l.p
		elseif dp > 0 and dq <= 0 then
			l.p = s(t)*l.q+s(1-t)*l.p
		elseif dp <= 0 and dq > 0 then
			l.q = s(t)*l.q+s(1-t)*l.p
		end
		
		return l
	end
	
	-- create a line from two pts
	function linpp(p,q)				
			local pq = q-p
			local n = v2(pq[2],-pq[1])*s(1/(sqrt(pq[1]*pq[1]+pq[2]*pq[2])))
			local d = dot(n,p)
			return {n=n,d=d,p=p,q=q}
	end
	
	-- create a line from pt+normal
	function linpn(p,n)
		return {n=n,p=p,d=dot(n,p)}
	end
	
	-- ccw
	-- return faces as normal
	-- plus end points
	function faces(body)
		local faces = {}
		local vert = hull_vert(body)
		
		for i=1,#vert do
			add(faces, linpp(vert[i],vert[i%#vert+1]))
		end
		
		return faces
	end
	
	-- finds support point of b
	-- for separating line f
	function find_support(b,n)
		local max_dist = 0x8000
		local max_idx = -1
		local vert = hull_vert(b)
		for i,v in ipairs(vert) do
			local dist = dot(n,v)
			if dist > max_dist then
				max_dist = dist
				max_idx = i
			end
		end
								
		return vert[max_idx]
	end
	
	function distance(face, point)
		return dot(face.n, point)-face.d
	end
	
	-- finds axis of max sep of
	-- a w/ respect to b
	-- ret: face of a w/ dist of
	-- 					support point of b max
	--						+dist +support
	function fquery(a,b)
		local fac = faces(a)
		local max_d = 0x8000
		local max_face, max_support
		
		for f in all(fac) do
			-- support point of b
			local s = find_support(b,-f.n)
			-- distance of support point
			local d = distance(f,s)
			
			if d > max_d then
				max_d = d
				max_face = f
				max_support = s
			end
		end
		
		return {f=max_face,s=max_support,sep=max_d}
	end

	local ab_query = fquery(a,b)
	local ba_query = fquery(b,a)

	local query
	local refb, incb
	if ba_query.sep*1.1 >= ab_query.sep then
		query = ba_query
		refb,incb = b,a
	else
		query = ab_query
		refb,incb = a,b
	end
	
	-- found axis with positive separation
	if query.sep > 0 then
		return nil
	end
	
	local ref = query.f
	
	local fac = faces(incb)
	local min_dot = 0x7fff
	local min_idx = -1
	for i,f in ipairs(fac) do
		local d = dot(f.n, ref.n)
		if d < min_dot then
			min_dot = d
			min_idx = i
		end
	end
	
	local inc = fac[min_idx]
	local lcl = linpn(ref.q, v2(-ref.n[2],ref.n[1]))
	local rcl = linpn(ref.p, v2(ref.n[2],-ref.n[1]))
	
	inc = lclip(lcl,inc)
	inc = lclip(rcl,inc)
	
	-- proj onto ref
	local pts = {}
	if dot(inc.p-ref.p,ref.n) <= 0 then
		local prop = inc.p-s(dot(inc.p-ref.p,ref.n))*ref.n
		add(pts,{prop, inc.p})
	end
	if dot(inc.q-ref.p,ref.n) <= 0 then
		local proq = inc.q-s(dot(inc.q-ref.p,ref.n))*ref.n
		add(pts,{proq, inc.q})
	end
	
	if (#pts == 0) return nil
	
	return {a=refb,b=incb,pts=pts, n=ref.n}
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0001000037600356001e6000d60000000000000060001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
