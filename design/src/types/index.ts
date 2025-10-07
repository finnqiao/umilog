export interface DiveSite {
  id: string;
  name: string;
  location: string;
  coordinates: {
    lat: number;
    lng: number;
  };
  region: string;
  averageDepth: number;
  maxDepth: number;
  averageTemp: number;
  averageVisibility: number;
  difficulty: 'Beginner' | 'Intermediate' | 'Advanced';
  type: 'Reef' | 'Wreck' | 'Wall' | 'Cave' | 'Shore' | 'Drift';
  description?: string;
}

export interface WildlifeSpecies {
  id: string;
  name: string;
  scientificName: string;
  region: string[];
  category: 'Fish' | 'Coral' | 'Mammal' | 'Invertebrate' | 'Reptile';
  rarity: 'Common' | 'Uncommon' | 'Rare' | 'Very Rare';
  imageUrl?: string;
}

export interface WildlifeSighting {
  speciesId: string;
  count: number;
  notes?: string;
}

export interface DiveLog {
  id: string;
  siteId: string;
  date: string;
  startTime: string;
  endTime?: string;
  maxDepth: number;
  averageDepth?: number;
  bottomTime: number;
  startPressure: number;
  endPressure: number;
  temperature: number;
  visibility: number;
  current: 'None' | 'Light' | 'Moderate' | 'Strong';
  conditions: 'Excellent' | 'Good' | 'Fair' | 'Poor';
  wildlife: WildlifeSighting[];
  notes: string;
  instructorName?: string;
  instructorNumber?: string;
  signed: boolean;
  photos?: string[];
  equipment?: {
    wetsuit: string;
    tank: string;
    weights: number;
  };
}

export interface Trip {
  id: string;
  name: string;
  startDate: string;
  endDate: string;
  location: string;
  diveIds: string[];
  photos?: string[];
}

export interface UserStats {
  totalDives: number;
  totalBottomTime: number;
  maxDepth: number;
  sitesVisited: number;
  speciesSpotted: number;
  certificationsLevel: string;
  divingSince: string;
}