import { DiveSite, WildlifeSpecies, DiveLog, Trip, UserStats } from '../types';

export const mockSites: DiveSite[] = [
  {
    id: '1',
    name: 'Great Barrier Reef',
    location: 'Queensland, Australia',
    coordinates: { lat: -16.2839, lng: 145.7781 },
    region: 'Pacific',
    averageDepth: 15,
    maxDepth: 30,
    averageTemp: 26,
    averageVisibility: 25,
    difficulty: 'Intermediate',
    type: 'Reef',
    description: 'World-famous coral reef system with incredible biodiversity'
  },
  {
    id: '2',
    name: 'Blue Hole',
    location: 'Belize',
    coordinates: { lat: 17.3182, lng: -87.5347 },
    region: 'Caribbean',
    averageDepth: 40,
    maxDepth: 124,
    averageTemp: 28,
    averageVisibility: 30,
    difficulty: 'Advanced',
    type: 'Wall',
    description: 'Iconic circular reef formation and deep blue sinkhole'
  },
  {
    id: '3',
    name: 'Manta Point',
    location: 'Nusa Penida, Indonesia',
    coordinates: { lat: -8.7292, lng: 115.5444 },
    region: 'Indo-Pacific',
    averageDepth: 18,
    maxDepth: 30,
    averageTemp: 27,
    averageVisibility: 20,
    difficulty: 'Intermediate',
    type: 'Drift',
    description: 'Famous manta ray cleaning station'
  },
  {
    id: '4',
    name: 'Cathedral Cove',
    location: 'Poor Knights Islands, New Zealand',
    coordinates: { lat: -35.4833, lng: 174.7333 },
    region: 'Pacific',
    averageDepth: 12,
    maxDepth: 25,
    averageTemp: 19,
    averageVisibility: 30,
    difficulty: 'Beginner',
    type: 'Cave',
    description: 'Stunning underwater archways and kelp forests'
  }
];

export const mockWildlife: WildlifeSpecies[] = [
  {
    id: '1',
    name: 'Clownfish',
    scientificName: 'Amphiprioninae',
    region: ['Indo-Pacific', 'Red Sea'],
    category: 'Fish',
    rarity: 'Common'
  },
  {
    id: '2',
    name: 'Manta Ray',
    scientificName: 'Mobula birostris',
    region: ['Indo-Pacific', 'Atlantic', 'Pacific'],
    category: 'Fish',
    rarity: 'Uncommon'
  },
  {
    id: '3',
    name: 'Green Sea Turtle',
    scientificName: 'Chelonia mydas',
    region: ['Indo-Pacific', 'Atlantic', 'Pacific', 'Caribbean'],
    category: 'Reptile',
    rarity: 'Uncommon'
  },
  {
    id: '4',
    name: 'Whale Shark',
    scientificName: 'Rhincodon typus',
    region: ['Indo-Pacific', 'Atlantic', 'Pacific'],
    category: 'Fish',
    rarity: 'Rare'
  },
  {
    id: '5',
    name: 'Octopus',
    scientificName: 'Octopoda',
    region: ['Indo-Pacific', 'Atlantic', 'Pacific', 'Caribbean'],
    category: 'Invertebrate',
    rarity: 'Common'
  },
  {
    id: '6',
    name: 'Hammerhead Shark',
    scientificName: 'Sphyrnidae',
    region: ['Indo-Pacific', 'Atlantic', 'Pacific'],
    category: 'Fish',
    rarity: 'Rare'
  }
];

export const mockDiveLogs: DiveLog[] = [
  {
    id: '1',
    siteId: '1',
    date: '2024-12-15',
    startTime: '09:30',
    endTime: '10:15',
    maxDepth: 18,
    averageDepth: 12,
    bottomTime: 45,
    startPressure: 200,
    endPressure: 50,
    temperature: 26,
    visibility: 25,
    current: 'Light',
    conditions: 'Excellent',
    wildlife: [
      { speciesId: '1', count: 12, notes: 'Large school near anemone garden' },
      { speciesId: '3', count: 1, notes: 'Juvenile turtle feeding on algae' }
    ],
    notes: 'Amazing visibility today! Saw a huge school of clownfish and a young turtle.',
    signed: false,
    equipment: {
      wetsuit: '5mm full suit',
      tank: '12L steel',
      weights: 6
    }
  },
  {
    id: '2',
    siteId: '3',
    date: '2024-12-10',
    startTime: '14:00',
    endTime: '14:50',
    maxDepth: 22,
    averageDepth: 18,
    bottomTime: 50,
    startPressure: 200,
    endPressure: 45,
    temperature: 27,
    visibility: 18,
    current: 'Moderate',
    conditions: 'Good',
    wildlife: [
      { speciesId: '2', count: 3, notes: 'Three mantas at cleaning station for entire dive!' }
    ],
    notes: 'Incredible manta encounter! They stayed at the cleaning station the whole time.',
    instructorName: 'Sarah Johnson',
    instructorNumber: 'PADI #123456',
    signed: true,
    equipment: {
      wetsuit: '3mm shorty',
      tank: '12L aluminum',
      weights: 4
    }
  }
];

export const mockTrips: Trip[] = [
  {
    id: '1',
    name: 'Great Barrier Reef Adventure',
    startDate: '2024-12-14',
    endDate: '2024-12-16',
    location: 'Cairns, Australia',
    diveIds: ['1']
  },
  {
    id: '2',
    name: 'Manta Point Expedition',
    startDate: '2024-12-08',
    endDate: '2024-12-12',
    location: 'Nusa Penida, Indonesia',
    diveIds: ['2']
  }
];

export const mockUserStats: UserStats = {
  totalDives: 47,
  totalBottomTime: 2340, // minutes
  maxDepth: 32,
  sitesVisited: 23,
  speciesSpotted: 89,
  certificationsLevel: 'Advanced Open Water',
  divingSince: '2022-03-15'
};