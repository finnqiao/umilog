import React, { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Label } from './ui/label';
import { Textarea } from './ui/textarea';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select';
import { Badge } from './ui/badge';
import { ArrowLeft, Calendar, MapPin, Upload, Zap, Plus, Trash2 } from 'lucide-react';
import { DiveSite, DiveLog } from '../types';

interface BackfillDive {
  date: string;
  siteId: string;
  maxDepth: string;
  bottomTime: string;
  temperature: string;
  notes: string;
}

interface BackfillWizardProps {
  sites: DiveSite[];
  onSave: (dives: Omit<DiveLog, 'id'>[]) => void;
  onBack: () => void;
}

export function BackfillWizard({ sites, onSave, onBack }: BackfillWizardProps) {
  const [currentStep, setCurrentStep] = useState(1);
  const [tripDates, setTripDates] = useState({
    startDate: '',
    endDate: '',
    location: ''
  });
  const [dives, setDives] = useState<BackfillDive[]>([]);
  const [isProcessing, setIsProcessing] = useState(false);

  // Auto-suggest sites based on trip location
  const suggestedSites = sites.filter(site => 
    tripDates.location && site.location.toLowerCase().includes(tripDates.location.toLowerCase()) ||
    site.region.toLowerCase().includes(tripDates.location.toLowerCase())
  );

  const generateDateRange = () => {
    if (!tripDates.startDate || !tripDates.endDate) return [];
    
    const start = new Date(tripDates.startDate);
    const end = new Date(tripDates.endDate);
    const dates = [];
    
    for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
      dates.push(new Date(d).toISOString().split('T')[0]);
    }
    
    return dates;
  };

  const generateSuggestedDives = () => {
    setIsProcessing(true);
    
    // Simulate processing time
    setTimeout(() => {
      const dateRange = generateDateRange();
      const suggestedDives: BackfillDive[] = [];
      
      dateRange.forEach((date, index) => {
        // Suggest 1-2 dives per day for a typical dive trip
        const divesPerDay = Math.random() > 0.3 ? 2 : 1;
        
        for (let i = 0; i < divesPerDay; i++) {
          const randomSite = suggestedSites.length > 0 
            ? suggestedSites[Math.floor(Math.random() * suggestedSites.length)]
            : sites[Math.floor(Math.random() * sites.length)];
          
          suggestedDives.push({
            date,
            siteId: randomSite.id,
            maxDepth: (randomSite.averageDepth + Math.random() * 10).toFixed(0),
            bottomTime: (35 + Math.random() * 20).toFixed(0),
            temperature: randomSite.averageTemp.toString(),
            notes: `Dive ${i + 1} on ${new Date(date).toLocaleDateString()}`
          });
        }
      });
      
      setDives(suggestedDives);
      setIsProcessing(false);
      setCurrentStep(3);
    }, 2000);
  };

  const addManualDive = () => {
    setDives(prev => [...prev, {
      date: tripDates.startDate,
      siteId: '',
      maxDepth: '',
      bottomTime: '',
      temperature: '',
      notes: ''
    }]);
  };

  const updateDive = (index: number, field: keyof BackfillDive, value: string) => {
    setDives(prev => prev.map((dive, i) => 
      i === index ? { ...dive, [field]: value } : dive
    ));
  };

  const removeDive = (index: number) => {
    setDives(prev => prev.filter((_, i) => i !== index));
  };

  const handleSubmit = () => {
    const completeDives: Omit<DiveLog, 'id'>[] = dives
      .filter(dive => dive.siteId && dive.maxDepth && dive.bottomTime)
      .map(dive => ({
        siteId: dive.siteId,
        date: dive.date,
        startTime: '10:00', // Default time
        maxDepth: parseFloat(dive.maxDepth) || 0,
        bottomTime: parseInt(dive.bottomTime) || 0,
        startPressure: 200, // Default pressure
        endPressure: 50, // Default end pressure
        temperature: parseFloat(dive.temperature) || 25,
        visibility: 20, // Default visibility
        current: 'Light' as const,
        conditions: 'Good' as const,
        wildlife: [],
        notes: dive.notes,
        signed: false,
        equipment: {
          wetsuit: '5mm full suit',
          tank: '12L aluminum',
          weights: 4
        }
      }));

    onSave(completeDives);
  };

  return (
    <div className="max-w-2xl mx-auto p-4 space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Button variant="ghost" size="sm" onClick={onBack}>
          <ArrowLeft className="w-4 h-4" />
        </Button>
        <div>
          <h1 className="text-2xl font-bold">Backfill Wizard</h1>
          <p className="text-muted-foreground">Add past dives in minutes</p>
        </div>
      </div>

      {/* Progress Bar */}
      <div className="w-full bg-muted rounded-full h-2">
        <div 
          className="bg-purple-600 h-2 rounded-full transition-all duration-300"
          style={{ width: `${(currentStep / 3) * 100}%` }}
        />
      </div>

      {/* Step 1: Trip Details */}
      {currentStep === 1 && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Calendar className="w-5 h-5 text-purple-600" />
              Trip Details
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <Label htmlFor="location">Trip Location</Label>
              <Input
                placeholder="e.g., Maldives, Great Barrier Reef, Red Sea"
                value={tripDates.location}
                onChange={(e) => setTripDates(prev => ({ ...prev, location: e.target.value }))}
              />
              <p className="text-sm text-muted-foreground mt-1">
                We'll suggest nearby dive sites based on this location
              </p>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label htmlFor="startDate">Start Date</Label>
                <Input
                  type="date"
                  value={tripDates.startDate}
                  onChange={(e) => setTripDates(prev => ({ ...prev, startDate: e.target.value }))}
                />
              </div>
              <div>
                <Label htmlFor="endDate">End Date</Label>
                <Input
                  type="date"
                  value={tripDates.endDate}
                  onChange={(e) => setTripDates(prev => ({ ...prev, endDate: e.target.value }))}
                />
              </div>
            </div>

            {tripDates.startDate && tripDates.endDate && (
              <div className="p-3 bg-muted rounded-lg">
                <p className="text-sm">
                  <strong>Trip Duration:</strong> {generateDateRange().length} days
                </p>
                {suggestedSites.length > 0 && (
                  <div className="mt-2">
                    <p className="text-sm font-medium">Nearby dive sites found:</p>
                    <div className="flex flex-wrap gap-1 mt-1">
                      {suggestedSites.slice(0, 3).map(site => (
                        <Badge key={site.id} variant="outline" className="text-xs">
                          {site.name}
                        </Badge>
                      ))}
                      {suggestedSites.length > 3 && (
                        <Badge variant="outline" className="text-xs">
                          +{suggestedSites.length - 3} more
                        </Badge>
                      )}
                    </div>
                  </div>
                )}
              </div>
            )}

            <Button 
              onClick={() => setCurrentStep(2)} 
              className="w-full"
              disabled={!tripDates.startDate || !tripDates.endDate || !tripDates.location}
            >
              Continue
            </Button>
          </CardContent>
        </Card>
      )}

      {/* Step 2: Auto-generation Options */}
      {currentStep === 2 && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Zap className="w-5 h-5 text-purple-600" />
              Smart Suggestions
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="text-center space-y-4">
              <div className="mx-auto w-16 h-16 bg-purple-100 dark:bg-purple-900 rounded-full flex items-center justify-center">
                <Zap className="w-8 h-8 text-purple-600" />
              </div>
              
              <div>
                <h3 className="font-semibold">Generate Dive Suggestions</h3>
                <p className="text-sm text-muted-foreground">
                  We'll create dive entries based on your trip dates and location. 
                  You can review and edit everything before saving.
                </p>
              </div>

              <div className="bg-muted p-4 rounded-lg text-left">
                <h4 className="font-medium mb-2">What we'll suggest:</h4>
                <ul className="text-sm text-muted-foreground space-y-1">
                  <li>• 1-2 dives per day based on typical dive trip patterns</li>
                  <li>• Nearby dive sites from our database</li>
                  <li>• Realistic depth and time estimates</li>
                  <li>• Regional temperature averages</li>
                </ul>
              </div>

              <div className="flex gap-4">
                <Button variant="outline" onClick={() => setCurrentStep(3)}>
                  <Plus className="w-4 h-4 mr-2" />
                  Add Manually
                </Button>
                <Button 
                  onClick={generateSuggestedDives}
                  disabled={isProcessing}
                  className="flex-1"
                >
                  {isProcessing ? (
                    <>
                      <div className="w-4 h-4 mr-2 border-2 border-white border-t-transparent rounded-full animate-spin" />
                      Generating...
                    </>
                  ) : (
                    <>
                      <Zap className="w-4 h-4 mr-2" />
                      Generate Suggestions
                    </>
                  )}
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Step 3: Review & Edit Dives */}
      {currentStep === 3 && (
        <div className="space-y-4">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0">
              <CardTitle>Review Dives ({dives.length})</CardTitle>
              <Button variant="outline" size="sm" onClick={addManualDive}>
                <Plus className="w-4 h-4 mr-2" />
                Add Dive
              </Button>
            </CardHeader>
            <CardContent className="space-y-4">
              {dives.length === 0 ? (
                <div className="text-center py-8">
                  <p className="text-muted-foreground mb-4">No dives added yet</p>
                  <Button onClick={addManualDive}>
                    <Plus className="w-4 h-4 mr-2" />
                    Add Your First Dive
                  </Button>
                </div>
              ) : (
                dives.map((dive, index) => (
                  <Card key={index} className="border-2">
                    <CardContent className="p-4">
                      <div className="flex items-center justify-between mb-3">
                        <h4 className="font-medium">Dive {index + 1}</h4>
                        <Button variant="ghost" size="sm" onClick={() => removeDive(index)}>
                          <Trash2 className="w-4 h-4" />
                        </Button>
                      </div>
                      
                      <div className="grid grid-cols-2 gap-3">
                        <div>
                          <Label className="text-xs">Date</Label>
                          <Input
                            type="date"
                            value={dive.date}
                            onChange={(e) => updateDive(index, 'date', e.target.value)}
                            className="text-sm"
                          />
                        </div>
                        <div>
                          <Label className="text-xs">Site</Label>
                          <Select value={dive.siteId} onValueChange={(value) => updateDive(index, 'siteId', value)}>
                            <SelectTrigger className="text-sm">
                              <SelectValue placeholder="Select site" />
                            </SelectTrigger>
                            <SelectContent>
                              {sites.map(site => (
                                <SelectItem key={site.id} value={site.id} className="text-sm">
                                  {site.name}
                                </SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        </div>
                        <div>
                          <Label className="text-xs">Max Depth (m)</Label>
                          <Input
                            type="number"
                            placeholder="18"
                            value={dive.maxDepth}
                            onChange={(e) => updateDive(index, 'maxDepth', e.target.value)}
                            className="text-sm"
                          />
                        </div>
                        <div>
                          <Label className="text-xs">Bottom Time (min)</Label>
                          <Input
                            type="number"
                            placeholder="45"
                            value={dive.bottomTime}
                            onChange={(e) => updateDive(index, 'bottomTime', e.target.value)}
                            className="text-sm"
                          />
                        </div>
                        <div>
                          <Label className="text-xs">Temperature (°C)</Label>
                          <Input
                            type="number"
                            placeholder="26"
                            value={dive.temperature}
                            onChange={(e) => updateDive(index, 'temperature', e.target.value)}
                            className="text-sm"
                          />
                        </div>
                        <div>
                          <Label className="text-xs">Notes</Label>
                          <Input
                            placeholder="Brief notes..."
                            value={dive.notes}
                            onChange={(e) => updateDive(index, 'notes', e.target.value)}
                            className="text-sm"
                          />
                        </div>
                      </div>
                    </CardContent>
                  </Card>
                ))
              )}
            </CardContent>
          </Card>

          {dives.length > 0 && (
            <div className="flex gap-4">
              <Button variant="outline" onClick={() => setCurrentStep(2)}>
                Back
              </Button>
              <Button onClick={handleSubmit} className="flex-1 bg-green-600 hover:bg-green-700">
                Save {dives.filter(d => d.siteId && d.maxDepth && d.bottomTime).length} Dives
              </Button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}