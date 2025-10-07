import React, { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { Button } from './ui/button';
import { Badge } from './ui/badge';
import { Input } from './ui/input';
import { ArrowLeft, Search, Calendar, MapPin, Thermometer, Eye, Clock, Fish, Award, FileText, Download } from 'lucide-react';
import { DiveLog, DiveSite, WildlifeSpecies } from '../types';

interface DiveHistoryProps {
  dives: DiveLog[];
  sites: DiveSite[];
  wildlife: WildlifeSpecies[];
  onBack: () => void;
  onExport: () => void;
}

export function DiveHistory({ dives, sites, wildlife, onBack, onExport }: DiveHistoryProps) {
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedDive, setSelectedDive] = useState<DiveLog | null>(null);

  const filteredDives = dives.filter(dive => {
    const site = sites.find(s => s.id === dive.siteId);
    return (
      site?.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      dive.notes.toLowerCase().includes(searchTerm.toLowerCase()) ||
      dive.date.includes(searchTerm)
    );
  });

  const getSiteForDive = (dive: DiveLog) => sites.find(s => s.id === dive.siteId);
  const getWildlifeSpecies = (speciesId: string) => wildlife.find(w => w.id === speciesId);

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  };

  const totalBottomTime = dives.reduce((sum, dive) => sum + dive.bottomTime, 0);
  const averageDepth = dives.length > 0 ? dives.reduce((sum, dive) => sum + dive.maxDepth, 0) / dives.length : 0;

  if (selectedDive) {
    const site = getSiteForDive(selectedDive);
    
    return (
      <div className="max-w-2xl mx-auto p-4 space-y-6">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="sm" onClick={() => setSelectedDive(null)}>
            <ArrowLeft className="w-4 h-4" />
          </Button>
          <div>
            <h1 className="text-2xl font-bold">Dive Details</h1>
            <p className="text-muted-foreground">{formatDate(selectedDive.date)}</p>
          </div>
        </div>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center justify-between">
              <span className="flex items-center gap-2">
                <MapPin className="w-5 h-5 text-blue-600" />
                {site?.name || 'Unknown Site'}
              </span>
              {selectedDive.signed && (
                <Badge variant="secondary" className="flex items-center gap-1">
                  <Award className="w-3 h-3" />
                  Signed
                </Badge>
              )}
            </CardTitle>
            {site && <p className="text-muted-foreground">{site.location}</p>}
          </CardHeader>
          <CardContent className="space-y-6">
            {/* Dive Metrics */}
            <div className="grid grid-cols-2 gap-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-blue-100 dark:bg-blue-900 rounded-full flex items-center justify-center">
                  <Thermometer className="w-5 h-5 text-blue-600" />
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">Max Depth</p>
                  <p className="font-semibold">{selectedDive.maxDepth}m</p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-green-100 dark:bg-green-900 rounded-full flex items-center justify-center">
                  <Clock className="w-5 h-5 text-green-600" />
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">Bottom Time</p>
                  <p className="font-semibold">{selectedDive.bottomTime}min</p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-orange-100 dark:bg-orange-900 rounded-full flex items-center justify-center">
                  <Thermometer className="w-5 h-5 text-orange-600" />
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">Temperature</p>
                  <p className="font-semibold">{selectedDive.temperature}°C</p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-teal-100 dark:bg-teal-900 rounded-full flex items-center justify-center">
                  <Eye className="w-5 h-5 text-teal-600" />
                </div>
                <div>
                  <p className="text-sm text-muted-foreground">Visibility</p>
                  <p className="font-semibold">{selectedDive.visibility}m</p>
                </div>
              </div>
            </div>

            {/* Pressure & Conditions */}
            <div className="space-y-3">
              <h3 className="font-semibold">Tank & Conditions</h3>
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <span className="text-muted-foreground">Start Pressure:</span>
                  <span className="ml-2">{selectedDive.startPressure} bar</span>
                </div>
                <div>
                  <span className="text-muted-foreground">End Pressure:</span>
                  <span className="ml-2">{selectedDive.endPressure} bar</span>
                </div>
                <div>
                  <span className="text-muted-foreground">Current:</span>
                  <span className="ml-2">{selectedDive.current}</span>
                </div>
                <div>
                  <span className="text-muted-foreground">Conditions:</span>
                  <span className="ml-2">{selectedDive.conditions}</span>
                </div>
              </div>
            </div>

            {/* Wildlife */}
            {selectedDive.wildlife.length > 0 && (
              <div className="space-y-3">
                <h3 className="font-semibold flex items-center gap-2">
                  <Fish className="w-4 h-4" />
                  Wildlife Spotted
                </h3>
                <div className="space-y-2">
                  {selectedDive.wildlife.map((sighting, index) => {
                    const species = getWildlifeSpecies(sighting.speciesId);
                    return (
                      <div key={index} className="flex items-center justify-between p-2 bg-muted rounded-lg">
                        <div>
                          <p className="font-medium">{species?.name || 'Unknown Species'}</p>
                          {species?.scientificName && (
                            <p className="text-sm text-muted-foreground italic">{species.scientificName}</p>
                          )}
                          {sighting.notes && (
                            <p className="text-sm text-muted-foreground">{sighting.notes}</p>
                          )}
                        </div>
                        <Badge variant="outline">
                          {sighting.count} {sighting.count === 1 ? 'spotted' : 'spotted'}
                        </Badge>
                      </div>
                    );
                  })}
                </div>
              </div>
            )}

            {/* Notes */}
            {selectedDive.notes && (
              <div className="space-y-3">
                <h3 className="font-semibold flex items-center gap-2">
                  <FileText className="w-4 h-4" />
                  Notes
                </h3>
                <p className="text-muted-foreground bg-muted p-3 rounded-lg">{selectedDive.notes}</p>
              </div>
            )}

            {/* Instructor Sign-off */}
            {selectedDive.signed && selectedDive.instructorName && (
              <div className="space-y-3">
                <h3 className="font-semibold flex items-center gap-2">
                  <Award className="w-4 h-4" />
                  Instructor Sign-off
                </h3>
                <div className="bg-green-50 dark:bg-green-900/20 p-3 rounded-lg border border-green-200 dark:border-green-800">
                  <p className="font-medium text-green-800 dark:text-green-200">{selectedDive.instructorName}</p>
                  {selectedDive.instructorNumber && (
                    <p className="text-sm text-green-600 dark:text-green-300">Certificate: {selectedDive.instructorNumber}</p>
                  )}
                  <p className="text-xs text-green-600 dark:text-green-400 mt-1">Digitally signed and verified</p>
                </div>
              </div>
            )}
          </CardContent>
        </Card>
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
          <h1 className="text-2xl font-bold">Dive History</h1>
          <p className="text-muted-foreground">{dives.length} dives logged</p>
        </div>
        <Button variant="outline" onClick={onExport}>
          <Download className="w-4 h-4 mr-2" />
          Export
        </Button>
      </div>

      {/* Stats Summary */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card>
          <CardContent className="p-4 text-center">
            <div className="text-2xl font-bold text-blue-600">{dives.length}</div>
            <p className="text-sm text-muted-foreground">Total Dives</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <div className="text-2xl font-bold text-green-600">{Math.round(totalBottomTime / 60)}h {totalBottomTime % 60}m</div>
            <p className="text-sm text-muted-foreground">Total Time Underwater</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <div className="text-2xl font-bold text-purple-600">{averageDepth.toFixed(1)}m</div>
            <p className="text-sm text-muted-foreground">Average Max Depth</p>
          </CardContent>
        </Card>
      </div>

      {/* Search */}
      <div className="relative">
        <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-muted-foreground w-4 h-4" />
        <Input
          placeholder="Search dives by site, notes, or date..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="pl-10"
        />
      </div>

      {/* Dive List */}
      <div className="space-y-4">
        {filteredDives.length === 0 ? (
          <Card>
            <CardContent className="p-8 text-center">
              <Fish className="w-12 h-12 mx-auto mb-4 text-muted-foreground" />
              <p className="text-muted-foreground">
                {searchTerm ? 'No dives match your search' : 'No dives logged yet'}
              </p>
            </CardContent>
          </Card>
        ) : (
          filteredDives
            .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())
            .map(dive => {
              const site = getSiteForDive(dive);
              return (
                <Card key={dive.id} className="hover:shadow-md transition-shadow cursor-pointer" onClick={() => setSelectedDive(dive)}>
                  <CardContent className="p-4">
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <div className="flex items-center gap-2 mb-2">
                          <h3 className="font-semibold">{site?.name || 'Unknown Site'}</h3>
                          {dive.signed && (
                            <Badge variant="secondary" className="text-xs">
                              <Award className="w-3 h-3 mr-1" />
                              Signed
                            </Badge>
                          )}
                        </div>
                        
                        <div className="flex items-center gap-4 text-sm text-muted-foreground mb-2">
                          <span className="flex items-center gap-1">
                            <Calendar className="w-3 h-3" />
                            {formatDate(dive.date)}
                          </span>
                          <span className="flex items-center gap-1">
                            <MapPin className="w-3 h-3" />
                            {site?.location || 'Unknown'}
                          </span>
                        </div>

                        <div className="flex items-center gap-6 text-sm">
                          <span className="flex items-center gap-1">
                            <Thermometer className="w-3 h-3 text-blue-600" />
                            {dive.maxDepth}m
                          </span>
                          <span className="flex items-center gap-1">
                            <Clock className="w-3 h-3 text-green-600" />
                            {dive.bottomTime}min
                          </span>
                          <span className="flex items-center gap-1">
                            <Thermometer className="w-3 h-3 text-orange-600" />
                            {dive.temperature}°C
                          </span>
                          <span className="flex items-center gap-1">
                            <Eye className="w-3 h-3 text-teal-600" />
                            {dive.visibility}m
                          </span>
                        </div>

                        {dive.wildlife.length > 0 && (
                          <div className="flex items-center gap-2 mt-2">
                            <Fish className="w-3 h-3 text-purple-600" />
                            <div className="flex flex-wrap gap-1">
                              {dive.wildlife.slice(0, 3).map((sighting, index) => {
                                const species = getWildlifeSpecies(sighting.speciesId);
                                return (
                                  <Badge key={index} variant="outline" className="text-xs">
                                    {species?.name}
                                  </Badge>
                                );
                              })}
                              {dive.wildlife.length > 3 && (
                                <Badge variant="outline" className="text-xs">
                                  +{dive.wildlife.length - 3} more
                                </Badge>
                              )}
                            </div>
                          </div>
                        )}

                        {dive.notes && (
                          <p className="text-sm text-muted-foreground mt-2 line-clamp-2">
                            {dive.notes}
                          </p>
                        )}
                      </div>
                    </div>
                  </CardContent>
                </Card>
              );
            })
        )}
      </div>
    </div>
  );
}