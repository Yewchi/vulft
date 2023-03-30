-- - #################################################################################### -
-- - - VUL-FT Full Takeover Bot Script for Dota 2 by yewchi // 'does stuff' on Steam
-- - - 
-- - - MIT License
-- - - 
-- - - Copyright (c) 2022 Michael, zyewchi@gmail.com, github.com/yewchi, gitlab.com/yewchi
-- - - 
-- - - Permission is hereby granted, free of charge, to any person obtaining a copy
-- - - of this software and associated documentation files (the "Software"), to deal
-- - - in the Software without restriction, including without limitation the rights
-- - - to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- - - copies of the Software, and to permit persons to whom the Software is
-- - - furnished to do so, subject to the following conditions:
-- - - 
-- - - The above copyright notice and this permission notice shall be included in all
-- - - copies or substantial portions of the Software.
-- - - 
-- - - THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- - - IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- - - FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- - - AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- - - LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- - - OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- - - SOFTWARE.
-- - #################################################################################### -

BOT_PERSONALITIES_I__NAME = 1
BOT_PERSONALITIES_I__TAKEN = 2

BOT_PERSONALITIES = {
	{"VUL-FT.Unrolled",		false},
	{"VUL-FT.Unabstracted", 	false},
	{"VUL-FT.64ByteEmptyTable", 		false},
	{"VUL-FT.LongVariableNameStringHash",		false},
	{"VUL-FT.NonCLibrary", 	false},
	{"VUL-FT.ContextSwitch", 		false},
	{"VUL-FT.DontGetJokes",		false},
	{"VUL-FT.300LocalGlobalReferences",		false},
	{"VUL-FT.OptimizeFirst",		false},
	{"VUL-FT.RecursiveCall",		false},
	{"VUL-FT.RecursiveRecursiveCallCall",	false},
	{"VUL-FT.CompiledOnThaFly",		false},
	{"VUL-FT.lua -O0",		false},
	{"VUL-FT.Name: [userdata]",	false},
	{"VUL-FT.GrayTableTier",	false}
}
