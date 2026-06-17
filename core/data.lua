--------------------------------------------------------
-- Namespaces
--------------------------------------------------------
local _, MCLcore = ...;

MCLcore.sectionNames = {}
MCLcore.mountList = {}

-- MoP Classic Mount Data
-- Only includes content available in MoP (5.4.8)

MCLcore.mountList[1] = {
	name = "MOP",
	categories = {
		Achievement = {
			name = "Achievement",
			mounts = {87769, 87773, 81559, 93662, 104208, 89785},
			mountID = {}
		},
		CloudSerpent = {
			name = "Order of the Cloud Serpent",
			mounts = {85430, 85429, 79802},
			mountID = {}
		},
		GoldenLotus = {
			name = "Golden Lotus",
			mounts = {87781, 87782, 87783},
			mountID = {}
		},
		KunLai = {
			name = "Kun-Lai Vendor",
			mounts = {87788, 87789, 84101},
			mountID = {}
		},
		PrimalEggs = {
			name = "Primal Eggs",
			mounts = {94291, 94292, 94293},
			mountID = {}
		},
		Quest = {
			name = "Quest",
			mounts = {93386, 87768, 94290, 93385},
			mountID = {}
		},
		RaidDrop = {
			name = "Raid Drop",
			mounts = {87777, 93666, 95059, 104253},
			mountID = {}
		},
		RareSpawn = {
			name = "Rare Spawn",
			mounts = {90655, 94229, 94230, 94231},
			mountID = {}
		},
		Reputation = {
			name = "Reputation",
			mounts = {93169, 95565, 81354, 89304, 85262, 89363, 87774, 93168, 95564},
			mountID = {}
		},
		ShadoPan = {
			name = "Shado-Pan",
			mounts = {89305, 89306, 89307},
			mountID = {}
		},
		TheTillers = {
			name = "The Tillers",
			mounts = {89362, 89390, 89391},
			mountID = {}
		},
		WorldBoss = {
			name = "World Boss",
			mounts = {94228, 87771, 89783, 95057, 104269},
			mountID = {}
		},
	}
}

MCLcore.mountList[2] = {
	name = "CATA",
	categories = {
		Achievement = {
			name = "Achievement",
			mounts = {62900, 62901, 69213, 69230, 77068},
			mountID = {}
		},
		DungeonDrop = {
			name = "Dungeon Drop",
			mounts = {69747, 63040, 63043, 68823, 68824},
			mountID = {}
		},
		Quest = {
			name = "Quest",
			mounts = {54465},
			mountID = {}
		},
		RaidDrop = {
			name = "Raid Drop",
			mounts = {77067, 77069, 78919, 63041, 69224, 71665},
			mountID = {}
		},
		RareSpawn = {
			name = "Rare Spawn",
			mounts = {67151, 63042, 63046},
			mountID = {}
		},
		Vendor = {
			name = "Vendor",
			mounts = {65356, 64999, 63044, 63045, 64998},
			mountID = {}
		},
	}
}

MCLcore.mountList[3] = {
	name = "WOTLK",
	categories = {
		Achievement = {
			name = "Achievement",
			mounts = {44160, 45801, 45802, 51954, 51955},
			mountID = {}
		},
		ArgentTournament = {
			name = "Argent Tournament",
			mounts = {46814, 45592, 45593, 45595, 45596, 45597, 46743, 46746, 46749, 46750, 46751, 46816, 47180, 45725, 45125, 45586, 45589, 45590, 45591, 46744, 46745, 46747, 46748, 46752, 46815, 46813},
			mountID = {}
		},
		DungeonDrop = {
			name = "Dungeon Drop",
			mounts = {43951, 44151},
			mountID = {}
		},
		Quest = {
			name = "Quest",
			mounts = {43962, 52200},
			mountID = {}
		},
		RaidDrop = {
			name = "Raid Drop",
			mounts = {43952, 43953, 43954, 43986, 49636, 43959, 45693, 50818, 44083, 206585},
			mountID = {}
		},
		RareSpawn = {
			name = "Rare Spawn",
			mounts = {44168},
			mountID = {}
		},
		Reputation = {
			name = "Reputation",
			mounts = {44080, 44086, 43955, 44707, 43958, 43961},
			mountID = {}
		},
		Vendor = {
			name = "Vendor",
			mounts = {44690, 44231, 44234, 44226, 44689, 44230, 44235, 44225},
			mountID = {}
		},
	}
}

MCLcore.mountList[4] = {
	name = "TBC",
	categories = {
		CenarionExpedition = {
			name = "Cenarion Expedition",
			mounts = {33999},
			mountID = {}
		},
		DungeonDrop = {
			name = "Dungeon Drop",
			mounts = {32768, 35513},
			mountID = {}
		},
		Kurenai = {
			name = "Kurenai/The Mag'har",
			mounts = {29227, 29231, 29229, 29230, 31830, 31832, 31834, 31836},
			mountID = {}
		},
		Netherwing = {
			name = "Netherwing",
			mounts = {32858, 32859, 32857, 32860, 32861, 32862},
			mountID = {}
		},
		RaidDrop = {
			name = "Raid Drop",
			mounts = {32458, 30480},
			mountID = {}
		},
		Shatari = {
			name = "Sha'tari Skyguard",
			mounts = {32319, 32314, 32316, 32317, 32318},
			mountID = {}
		},
		Vendor = {
			name = "Vendor",
			mounts = {25473, 25527, 25528, 25529, 25470, 25471, 25472, 25477, 25531, 25532, 25533, 25474, 25475, 25476},
			mountID = {}
		},
	}
}

MCLcore.mountList[5] = {
	name = "Classic",
	categories = {
		DungeonDrop = {
			name = "Dungeon Drop",
			mounts = {13335},
			mountID = {}
		},
		RaidDrop = {
			name = "Raid Drop",
			mounts = {21218, 21321, 21323, 21324},
			mountID = {}
		},
		Reputation = {
			name = "Reputation",
			mounts = {13086, 46102},
			mountID = {}
		},
	}
}

MCLcore.mountList[6] = {
	name = "Alliance",
	categories = {
		Draenei = {
			name = "Draenei",
			mounts = {29745, 29746, 29747, 28481, 29743, 29744},
			mountID = {}
		},
		Dwarf = {
			name = "Dwarf",
			mounts = {18785, 18786, 18787, 5864, 5872, 5873},
			mountID = {}
		},
		Gnome = {
			name = "Gnome",
			mounts = {18772, 18773, 18774, 8563, 8595, 13322, 13321},
			mountID = {}
		},
		Human = {
			name = "Human",
			mounts = {18776, 18777, 18778, 5655, 2411, 2414, 5656},
			mountID = {}
		},
		NightElf = {
			name = "Night Elf",
			mounts = {18766, 18767, 18902, 8629, 8631, 8632, 47100},
			mountID = {}
		},
		Pandaren = {
			name = "Pandaren",
			mounts = {91010, 91012, 91011, 91013, 91014, 91015, 91004, 91008, 91009, 91005, 91006, 91007},
			mountID = {}
		},
	}
}

MCLcore.mountList[7] = {
	name = "Horde",
	categories = {
		Bloodelf = {
			name = "Blood Elf",
			mounts = {28936, 29223, 29224, 28927, 29220, 29221, 29222},
			mountID = {}
		},
		Goblin = {
			name = "Goblin",
			mounts = {62462, 62461},
			mountID = {}
		},
		Orc = {
			name = "Orc",
			mounts = {18796, 18798, 18797, 46099, 5668, 5665, 1132},
			mountID = {}
		},
		Pandaren = {
			name = "Pandaren",
			mounts = {91010, 91012, 91011, 91013, 91014, 91015, 91004, 91008, 91009, 91005, 91006, 91007},
			mountID = {}
		},
		Tauren = {
			name = "Tauren",
			mounts = {18793, 18794, 18795, 15277, 15290, 46100},
			mountID = {}
		},
		Troll = {
			name = "Troll",
			mounts = {18788, 18789, 18790, 8588, 8591, 8592},
			mountID = {}
		},
		Undead = {
			name = "Undead",
			mounts = {13334, 18791, 13331, 13332, 13333, 46308, 47101},
			mountID = {}
		},
	}
}

MCLcore.mountList[8] = {
	name = "Professions",
	categories = {
		Alchemy = {
			name = "Alchemy",
			mounts = {65891},
			mountID = {}
		},
		Archeology = {
			name = "Archeology",
			mounts = {60954, 64883},
			mountID = {}
		},
		Engineering = {
			name = "Engineering",
			mounts = {34060, 41508, 34061, 44413, 87250, 87251, 95416},
			mountID = {}
		},
		Fishing = {
			name = "Fishing",
			mounts = {46109, 23720},
			mountID = {}
		},
		Jewelcrafting = {
			name = "Jewelcrafting",
			mounts = {83088, 83087, 83090, 83089, 82453},
			mountID = {}
		},
		Tailoring = {
			name = "Tailoring",
			mounts = {44554, 54797, 44558},
			mountID = {}
		},
	}
}

MCLcore.mountList[9] = {
	name = "PVP",
	categories = {
		Achievement = {
			name = "Achievement",
			mounts = {44223, 44224},
			mountID = {}
		},
		Halaa = {
			name = "Halaa",
			mounts = {28915, 29228},
			mountID = {}
		},
		Honor = {
			name = "Honor",
			mounts = {19030, 29465, 29467, 29468, 29471, 35906, 43956, 29466, 29469, 29470, 29472, 19029, 34129, 44077},
			mountID = {}
		},
		TimelessIsle = {
			name = "Timeless Isle",
			mounts = {103638},
			mountID = {}
		},
		ViciousSaddle = {
			name = "Vicious Saddle",
			mounts = {102533, 70910, 70909, 102514},
			mountID = {}
		},
	}
}

MCLcore.mountList[10] = {
	name = "WorldEvents",
	categories = {
		Achievement = {
			name = "Achievement",
			mounts = {44177},
			mountID = {}
		},
		Brewfest = {
			name = "Brewfest",
			mounts = {33977, 37828},
			mountID = {}
		},
		DarkmoonFaire = {
			name = "Darkmoon Faire",
			mounts = {72140, 73766},
			mountID = {}
		},
		HallowsEnd = {
			name = "Hallow's End",
			mounts = {37012},
			mountID = {}
		},
		LoveAir = {
			name = "Love is in the Air",
			mounts = {72146, 50250},
			mountID = {}
		},
		NobleGarden = {
			name = "Noblegarden",
			mounts = {72145},
			mountID = {}
		},
	}
}

MCLcore.mountList[11] = {
	name = "Other",
	categories = {
		BMAH = {
			name = "BMAH",
			mounts = {19872, 19902, 44175},
			mountID = {}
		},
		DeathKnight = {
			name = "Death Knight",
			mounts = {40775},
			mountID = {}
		},
		GuildVendor = {
			name = "Guild Vendor",
			mounts = {63125, 62298, 67107, 85666},
			mountID = {}
		},
		MountCollection = {
			name = "Mount Collection",
			mounts = {44178, 44843, 44842, 98104, 91802, 98259, 69226, 87776},
			mountID = {}
		},
		Paladin = {
			name = "Paladin",
			mounts = {47179, "m41", "m84", "m149", "m150", "m350", "m351", "m367", "m368"},
			mountID = {41, 84, 149, 150, 350, 351, 367, 368}
		},
		Warlock = {
			name = "Warlock",
			mounts = {"m17", "m83"},
			mountID = {17, 83}
		},
	}
}

-- Regional filters for certain regions (empty for MoP Classic)
MCLcore.regionalFilter = {
	-- Add region-specific filters here if needed
	-- Example: CN = {itemID1, itemID2}
}
