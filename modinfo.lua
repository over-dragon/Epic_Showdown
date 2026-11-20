local modid = 'epic_showdown'
local cur = (locale == 'zh' or locale == 'zhr') and 'zh' or 'en'

version = '26.11.04'
author = 'over_dragon、Guto'

forumthread = ''
api_version = 10
priority = -1000 -- 加载优先级，越低加载越晚，默认为0

dst_compatible = true -- 联机版适配性
dont_starve_compatible = false -- 单机版适配性
reign_of_giants_compatible = false -- 单机版：巨人国适配性
all_clients_require_mod = true -- 服务端/所有端模组
-- server_only_mod = true -- 仅服务端模组
-- client_only_mod = true -- 仅客户端模组
server_filter_tags = {} -- 创意工坊模组分类标签
icon_atlas = 'modicon.xml' -- 图集
icon = 'modicon.tex' -- 图标

local op={{'A',97},{'B',98},{'C',99},{'D',100},{'E',101},{'F',102},{'G',103},
{'H',104},{'I',105},{'J',106},{'K',107},{'L',108},{'M',109},{'N',110},{'O',111},
{'P',112},{'Q',113},{'R',114},{'无/None',0},{'S',115},{'T',116},{'U',117},{'V',118},{'W',119},
{'X',120},{'Y',121},{'Z',122},{'0',48},{'1',49},{'2',50},{'3',51},{'4',52},{'5',53},
{'6',54},{'7',55},{'8',56},{'9',57}}

local padop = {
    {'无/None',0},
    {'LT',46},           -- CONTROL_OPEN_CRAFTING
    {'RT',45},           -- CONTROL_OPEN_INVENTORY
    {'DPad Up',51},    -- CONTROL_INVENTORY_EXAMINE
    {'DPad Down',54},  -- CONTROL_INVENTORY_DROP
    {'DPad Left',53},  -- CONTROL_INVENTORY_USEONSCENE
    {'DPad Right',52}, -- CONTROL_INVENTORY_USEONSELF
}

local LANGS = {
    ['zh'] = {
        name = '史诗对决',
        description = '史诗对决，BOSS之间的战斗，获取BOSS的力量，变身为BOSS，大杀四方，目前共有20个BOSS。',
        config = {
            {'通用'},
            {modid..'_health','生命值倍率','以原版为基础，如果有其它模组修改了常量表那么也会相应改变',0.5,{
                {'0.25',0.25},
                {'0.50',0.5},
                {'0.75',0.75},
                {'1.00',1},
                {'1.25',1.25},
                {'1.50',1.5},
                {'1.75',1.75},
                {'2.00',2}
            }},
            {modid..'_damage','物理伤害倍率','以原版为基础，如果有其它模组修改了常量表那么也会相应改变',1,{
                {'0.50',0.5},
                {'1.00',1},
                {'1.50',1.5},
                {'2.00',2},
                {'3.00',3}
            }},
            {modid..'_BGM','BOSS状态专属BGM','对应BOSS的战斗音乐',1,{
                {'关闭',0},
                {'开启',1}
            }},
            {modid..'_caselect_music','技能施法音效','',1,{
                {'关闭',0},
                {'开启',1}
            }},
            {modid..'_structure_protection','基地保护','开启后大部分BOSS技能将不会破坏建筑、墙，挖的工作对象只对树桩生效',1,{
                {'关闭',0},
                {'开启',1}
            }},
            {modid..'_attack_move','允许走A','',1,{
                {'关闭',0},
                {'开启',1}
            }},
            {modid..'_recipes','配方方案','',0,{
                {'默认',0},
                {'方案1',1},
                {'方案2',2}
            }},
            {modid..'_mat','默认方案主材料数量倍率','取整数',1,{
                {'0',0},
                {'0.5',0.5},
                {'1',1},
                {'2',2},
                {'3',3},
                {'4',4},
            }},
            {modid..'walkspeed_change','行走速度修正','仅对部分boss生效',0,{
                {'关闭',0},
                {'开启',1}
            }},
            {modid..'_combat_target','仇恨索敌','开启后对于友好生物伤害目标从可以攻击的目标变更为对自身有仇恨或自己仇恨的目标',1,{
                {'关闭',0},
                {'开启',1},
            }},
            {'PVP模式下生效'},
            {modid..'_keepsake','初始道具','除了无，剩下两个选项会从BOSS池里面随机抽取',1,{
                {'无',0},
                {'信物',1},
                {'本源',2},
            }},
            {'技能快捷键'},
            {modid..'taunt_keydown','战吼','',0,op},
            {modid..'transform_keydown','形态切换','',0,op},
            {modid..'onbecamehuman_keydown','解除变身','',0,op},
            {modid..'skill1_keydown','技能1','',0,op},
            {modid..'skill2_keydown','技能2','',0,op},
            {modid..'skill3_keydown','技能3','',0,op},
            {modid..'_castselect_hide_key','轮盘显隐','仅变身状态有用，控制施法轮盘的显示和隐藏',0,op},
            {'手柄施法键'},
            {modid..'_pad_cast','手柄施法键','按住+右摇杆选择技能，松开施法；摇杆回中松开=取消',46,padop},
        }
    },
    ['en'] = {
        name = 'Epic Showdown',
        description = 'Epic Showdown - Battle among BOSSes. Harness their power, transform into a BOSS, and dominate the battlefield. Currently supports 20 BOSSes.',
        config = {
            {'General'},
            {modid..'_health','Health Multiplier','Based on vanilla values. If other mods modify the constant tables, this will change accordingly.',0.5,{
                {'0.25',0.25},
                {'0.50',0.5},
                {'0.75',0.75},
                {'1.00',1},
                {'1.25',1.25},
                {'1.50',1.5},
                {'1.75',1.75},
                {'2.00',2}
            }},
            {modid..'_damage','Physical Damage Multiplier','Based on vanilla values. If other mods modify the constant tables, this will change accordingly.',1,{
                {'0.50',0.5},
                {'1.00',1},
                {'1.50',1.5},
                {'2.00',2},
                {'3.00',3}
            }},
            {modid..'_BGM','BOSS State Exclusive BGM','Battle music corresponding to each BOSS.',1,{
                {'Disabled',0},
                {'Enabled',1}
            }},
            {modid..'_caselect_music','Skill Casting Sound Effect','',1,{
                {'Disabled',0},
                {'Enabled',1}
            }},
            {modid..'_structure_protection','Base Protection','When enabled, most BOSS skills will not destroy structures or walls; mining interactions will only target tree stumps.',1,{
                {'Disabled',0},
                {'Enabled',1}
            }},
            {modid..'_attack_move','Allow Attack While Moving','',1,{
                {'Disabled',0},
                {'Enabled',1}
            }},
            {modid..'_recipes','Recipe Scheme','',0,{
                {'Default',0},
                {'Scheme 1',1},
                {'Scheme 2',2}
            }},
            {modid..'_mat','Default Scheme Main Material Quantity Multiplier','Rounded to integer',1,{
                {'0',0},
                {'0.5',0.5},
                {'1',1},
                {'2',2},
                {'3',3},
                {'4',4},
            }},
            {modid..'walkspeed_change','Walk Speed Modification','Only affects certain bosses.',0,{
                {'Disabled',0},
                {'Enabled',1}
            }},
            {modid..'_combat_target','Aggro Targeting','When enabled, damage targets for friendly creatures are changed from any attackable target to only those that have aggro on you or that you are hostile to.',1,{
                {'Disabled',0},
                {'Enabled',1},
            }},
            {'Effective in PVP Mode'},
            {modid..'_keepsake','Starting Item','Aside from "None", the other two options will be randomly selected from the boss pool.',1,{
                {'None',0},
                {'Keepsake',1},
                {'Essence',2},
            }},
            {'Skill Hotkeys'},
            {modid..'taunt_keydown','Taunt','',0,op},
            {modid..'transform_keydown','Form Switch','',0,op},
            {modid..'onbecamehuman_keydown','Revert Form','',0,op},
            {modid..'skill1_keydown','Skill 1','',0,op},
            {modid..'skill2_keydown','Skill 2','',0,op},
            {modid..'skill3_keydown','Skill 3','',0,op},
            {modid..'_castselect_hide_key','Radial Menu Visibility','Only affects transformed state. Controls the visibility of the casting radial menu.',0,op},
            {'Gamepad Cast Key'},
            {modid..'_pad_cast','Gamepad Cast Key','Hold + right stick to select a skill, release to cast.',46,padop},
        }
    }
}

name = LANGS[cur].name
description = version..'\n'..LANGS[cur].description
local config = LANGS[cur].config or {}
local _configuration_options = {}
for i = 1, #config do
    local options = {}
    if config[i][5] then
        for k = 1, #config[i][5] do
            options[k] = {description = config[i][5][k][1], data = config[i][5][k][2]}
        end
    end
    _configuration_options[i] = {
        name = config[i][1],
        label = config[i][2],
        hover = config[i][3] or '',
        default = config[i][4] or false,
        options = #options>0 and options or {{description = "", data = false}},
    }
end

configuration_options = _configuration_options