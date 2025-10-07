import React, { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { Button } from './ui/button';
import { Badge } from './ui/badge';
import { Input } from './ui/input';
import { ArrowLeft, Search, MapPin, Thermometer, Eye, Plus, Navigation, Star, Filter } from 'lucide-react';
import { DiveSite } from '../types';
import { ImageWithFallback } from './figma/ImageWithFallback';

interface SiteExplorerProps {
  sites: DiveSite[];
  visitedSiteIds: string[];
  onBack: () => void;
  onSelectSite: (siteId: string) => void;
  onAddNewSite: () => void;
}

export function SiteExplorer({ sites, visitedSiteIds, onBack, onSelectSite, onAddNewSite }: SiteExplorerProps) {
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedRegion, setSelectedRegion] = useState<string>('all');
  const [selectedDifficulty, setSelectedDifficulty] = useState<string>('all');
  const [viewMode, setViewMode] = useState<'list' | 'map'>('list');

  const regions = ['all', ...Array.from(new Set(sites.map(site => site.region)))];
  const difficulties = ['all', 'Beginner', 'Intermediate', 'Advanced'];

  const filteredSites = sites.filter(site => {
    const matchesSearch = site.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         site.location.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         site.description?.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesRegion = selectedRegion === 'all' || site.region === selectedRegion;
    const matchesDifficulty = selectedDifficulty === 'all' || site.difficulty === selectedDifficulty;
    
    return matchesSearch && matchesRegion && matchesDifficulty;
  });

  const visitedSites = filteredSites.filter(site => visitedSiteIds.includes(site.id));
  const unvisitedSites = filteredSites.filter(site => !visitedSiteIds.includes(site.id));

  const getDifficultyColor = (difficulty: string) => {
    switch (difficulty) {
      case 'Beginner': return 'bg-green-100 text-green-800 border-green-200';
      case 'Intermediate': return 'bg-yellow-100 text-yellow-800 border-yellow-200';
      case 'Advanced': return 'bg-red-100 text-red-800 border-red-200';
      default: return 'bg-gray-100 text-gray-800 border-gray-200';
    }
  };

  const getTypeIcon = (type: string) => {
    switch (type) {
      case 'Reef': return '🪸';
      case 'Wreck': return '🚢';
      case 'Wall': return '🧱';
      case 'Cave': return '🕳️';
      case 'Shore': return '🏖️';
      case 'Drift': return '🌊';
      default: return '🌊';
    }
  };

  if (viewMode === 'map') {
    return (
      <div className="max-w-4xl mx-auto p-4 space-y-6">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="sm" onClick={onBack}>
            <ArrowLeft className="w-4 h-4" />
          </Button>
          <div className="flex-1">
            <h1 className="text-2xl font-bold">Dive Site Map</h1>
            <p className="text-muted-foreground">{sites.length} sites worldwide</p>
          </div>
          <Button variant="outline" onClick={() => setViewMode('list')}>
            List View
          </Button>
        </div>

        <Card className="overflow-hidden">
          <div className="relative h-96">
            <ImageWithFallback 
              src="https://images.unsplash.com/photo-1713098965471-d324f294a71d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx3b3JsZCUyMG1hcCUyMGRpdmluZyUyMGxvY2F0aW9uc3xlbnwxfHx8fDE3NTk4MjAxNDJ8MA&ixlib=rb-4.1.0&q=80&w=1080&utm_source=figma&utm_medium=referral"
              alt="World map with dive sites"
              className="w-full h-full object-cover"
            />
            <div className="absolute inset-0 bg-gradient-to-t from-black/30 to-transparent" />
            
            {/* Mock map pins */}
            <div className="absolute top-1/4 left-1/4 w-4 h-4 bg-blue-600 rounded-full border-2 border-white shadow-lg cursor-pointer hover:scale-110 transition-transform" title="Great Barrier Reef" />
            <div className="absolute top-1/3 left-1/2 w-4 h-4 bg-green-600 rounded-full border-2 border-white shadow-lg cursor-pointer hover:scale-110 transition-transform" title="Blue Hole, Belize" />
            <div className="absolute top-2/3 right-1/3 w-4 h-4 bg-purple-600 rounded-full border-2 border-white shadow-lg cursor-pointer hover:scale-110 transition-transform" title="Manta Point, Indonesia" />
            <div className="absolute bottom-1/4 right-1/4 w-4 h-4 bg-teal-600 rounded-full border-2 border-white shadow-lg cursor-pointer hover:scale-110 transition-transform" title="Poor Knights Islands, NZ" />
            
            <div className="absolute bottom-4 left-4 text-white">
              <h3 className="text-lg font-semibold">Interactive Dive Site Map</h3>
              <p className="text-sm opacity-90">Click on pins to explore sites</p>
            </div>
          </div>
        </Card>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {sites.map(site => (
            <Card key={site.id} className="hover:shadow-md transition-shadow cursor-pointer" onClick={() => onSelectSite(site.id)}>
              <CardContent className="p-4">
                <div className="flex items-start justify-between mb-2">
                  <h3 className="font-semibold">{site.name}</h3>
                  {visitedSiteIds.includes(site.id) && (
                    <Badge variant="secondary" className="text-xs">
                      <Star className="w-3 h-3 mr-1 fill-current" />
                      Visited
                    </Badge>
                  )}
                </div>
                <p className="text-sm text-muted-foreground mb-2">{site.location}</p>
                <div className="flex items-center gap-2 text-xs">
                  <span>{getTypeIcon(site.type)} {site.type}</span>
                  <Badge className={`text-xs ${getDifficultyColor(site.difficulty)}`}>
                    {site.difficulty}
                  </Badge>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto p-4 space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Button variant="ghost" size="sm" onClick={onBack}>
          <ArrowLeft className="w-4 h-4" />
        </Button>
        <div className="flex-1">
          <h1 className="text-2xl font-bold">Dive Sites</h1>
          <p className="text-muted-foreground">{visitedSites.length} visited • {unvisitedSites.length} to explore</p>
        </div>
        <Button variant="outline" onClick={() => setViewMode('map')}>
          <MapPin className="w-4 h-4 mr-2" />
          Map View
        </Button>
        <Button onClick={onAddNewSite}>
          <Plus className="w-4 h-4 mr-2" />
          Add Site
        </Button>
      </div>

      {/* Search and Filters */}
      <div className="flex flex-col md:flex-row gap-4">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-muted-foreground w-4 h-4" />
          <Input
            placeholder="Search sites by name, location, or description..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-10"
          />
        </div>
        
        <div className="flex gap-2">
          <select 
            value={selectedRegion}
            onChange={(e) => setSelectedRegion(e.target.value)}
            className="px-3 py-2 border border-border rounded-md text-sm bg-background"
          >
            {regions.map(region => (
              <option key={region} value={region}>
                {region === 'all' ? 'All Regions' : region}
              </option>
            ))}
          </select>
          
          <select 
            value={selectedDifficulty}
            onChange={(e) => setSelectedDifficulty(e.target.value)}
            className="px-3 py-2 border border-border rounded-md text-sm bg-background"
          >
            {difficulties.map(difficulty => (
              <option key={difficulty} value={difficulty}>
                {difficulty === 'all' ? 'All Levels' : difficulty}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Quick Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="p-4 text-center">
            <div className="text-2xl font-bold text-blue-600">{sites.length}</div>
            <p className="text-sm text-muted-foreground">Total Sites</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <div className="text-2xl font-bold text-green-600">{visitedSites.length}</div>
            <p className="text-sm text-muted-foreground">Visited</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <div className="text-2xl font-bold text-purple-600">{regions.length - 1}</div>
            <p className="text-sm text-muted-foreground">Regions</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <div className="text-2xl font-bold text-orange-600">{unvisitedSites.length}</div>
            <p className="text-sm text-muted-foreground">Wishlist</p>
          </CardContent>
        </Card>
      </div>

      {/* Visited Sites */}
      {visitedSites.length > 0 && (
        <div>
          <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
            <Star className="w-5 h-5 text-yellow-500 fill-current" />
            Visited Sites ({visitedSites.length})
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {visitedSites.map(site => (
              <Card key={site.id} className="hover:shadow-md transition-shadow cursor-pointer" onClick={() => onSelectSite(site.id)}>
                <CardContent className="p-4">
                  <div className="flex items-start justify-between mb-2">
                    <h3 className="font-semibold">{site.name}</h3>
                    <Badge variant="secondary" className="text-xs bg-green-100 text-green-800 border-green-200">
                      <Star className="w-3 h-3 mr-1 fill-current" />
                      Visited
                    </Badge>
                  </div>
                  
                  <p className="text-sm text-muted-foreground mb-3">{site.location}</p>
                  
                  <div className="space-y-2">
                    <div className="flex items-center justify-between text-sm">
                      <span className="flex items-center gap-1">
                        {getTypeIcon(site.type)} {site.type}
                      </span>
                      <Badge className={`text-xs ${getDifficultyColor(site.difficulty)}`}>
                        {site.difficulty}
                      </Badge>
                    </div>
                    
                    <div className="flex items-center gap-4 text-xs text-muted-foreground">
                      <span className="flex items-center gap-1">
                        <Navigation className="w-3 h-3" />
                        {site.maxDepth}m
                      </span>
                      <span className="flex items-center gap-1">
                        <Thermometer className="w-3 h-3" />
                        {site.averageTemp}°C
                      </span>
                      <span className="flex items-center gap-1">
                        <Eye className="w-3 h-3" />
                        {site.averageVisibility}m
                      </span>
                    </div>
                  </div>
                  
                  {site.description && (
                    <p className="text-xs text-muted-foreground mt-2 line-clamp-2">{site.description}</p>
                  )}
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      )}

      {/* Unvisited Sites (Wishlist) */}
      <div>
        <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
          <MapPin className="w-5 h-5 text-blue-600" />
          Explore New Sites ({unvisitedSites.length})
        </h2>
        
        {unvisitedSites.length === 0 ? (
          <Card>
            <CardContent className="p-8 text-center">
              <MapPin className="w-12 h-12 mx-auto mb-4 text-muted-foreground" />
              <p className="text-muted-foreground">
                {searchTerm || selectedRegion !== 'all' || selectedDifficulty !== 'all' 
                  ? 'No sites match your filters' 
                  : 'You\'ve visited all available sites!'}
              </p>
              {(!searchTerm && selectedRegion === 'all' && selectedDifficulty === 'all') && (
                <Button className="mt-4" onClick={onAddNewSite}>
                  <Plus className="w-4 h-4 mr-2" />
                  Add New Site
                </Button>
              )}
            </CardContent>
          </Card>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {unvisitedSites.map(site => (
              <Card key={site.id} className="hover:shadow-md transition-shadow cursor-pointer" onClick={() => onSelectSite(site.id)}>
                <CardContent className="p-4">
                  <div className="flex items-start justify-between mb-2">
                    <h3 className="font-semibold">{site.name}</h3>
                    <Badge variant="outline" className="text-xs">
                      Wishlist
                    </Badge>
                  </div>
                  
                  <p className="text-sm text-muted-foreground mb-3">{site.location}</p>
                  
                  <div className="space-y-2">
                    <div className="flex items-center justify-between text-sm">
                      <span className="flex items-center gap-1">
                        {getTypeIcon(site.type)} {site.type}
                      </span>
                      <Badge className={`text-xs ${getDifficultyColor(site.difficulty)}`}>
                        {site.difficulty}
                      </Badge>
                    </div>
                    
                    <div className="flex items-center gap-4 text-xs text-muted-foreground">
                      <span className="flex items-center gap-1">
                        <Navigation className="w-3 h-3" />
                        {site.maxDepth}m
                      </span>
                      <span className="flex items-center gap-1">
                        <Thermometer className="w-3 h-3" />
                        {site.averageTemp}°C
                      </span>
                      <span className="flex items-center gap-1">
                        <Eye className="w-3 h-3" />
                        {site.averageVisibility}m
                      </span>
                    </div>
                  </div>
                  
                  {site.description && (
                    <p className="text-xs text-muted-foreground mt-2 line-clamp-2">{site.description}</p>
                  )}
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}