import React, { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Label } from './ui/label';
import { Textarea } from './ui/textarea';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select';
import { Badge } from './ui/badge';
import { ArrowLeft, Mic, MapPin, Thermometer, Eye, Clock, Gauge } from 'lucide-react';
import { DiveSite, WildlifeSpecies, DiveLog, WildlifeSighting } from '../types';

interface DiveLoggerProps {
  sites: DiveSite[];
  wildlife: WildlifeSpecies[];
  onSave: (dive: Omit<DiveLog, 'id'>) => void;
  onBack: () => void;
  selectedSiteId?: string;
}

export function DiveLogger({ sites, wildlife, onSave, onBack, selectedSiteId }: DiveLoggerProps) {
  const [currentStep, setCurrentStep] = useState(1);
  const [isRecording, setIsRecording] = useState(false);
  
  // Form state
  const [formData, setFormData] = useState({
    siteId: selectedSiteId || '',
    date: new Date().toISOString().split('T')[0],
    startTime: '',
    endTime: '',
    maxDepth: '',
    averageDepth: '',
    bottomTime: '',
    startPressure: '200',
    endPressure: '',
    temperature: '',
    visibility: '',
    current: 'None' as const,
    conditions: 'Good' as const,
    notes: '',
    instructorName: '',
    instructorNumber: '',
    equipment: {
      wetsuit: '',
      tank: '',
      weights: ''
    }
  });

  const [selectedWildlife, setSelectedWildlife] = useState<WildlifeSighting[]>([]);

  const selectedSite = sites.find(site => site.id === formData.siteId);

  const handleVoiceInput = () => {
    setIsRecording(!isRecording);
    // Mock voice input functionality
    if (!isRecording) {
      setTimeout(() => {
        setFormData(prev => ({
          ...prev,
          notes: prev.notes + (prev.notes ? ' ' : '') + 'Amazing visibility today, saw lots of marine life!'
        }));
        setIsRecording(false);
      }, 2000);
    }
  };

  const addWildlifeSighting = (speciesId: string) => {
    const existing = selectedWildlife.find(w => w.speciesId === speciesId);
    if (existing) {
      setSelectedWildlife(prev => 
        prev.map(w => w.speciesId === speciesId ? { ...w, count: w.count + 1 } : w)
      );
    } else {
      setSelectedWildlife(prev => [...prev, { speciesId, count: 1, notes: '' }]);
    }
  };

  const removeWildlifeSighting = (speciesId: string) => {
    setSelectedWildlife(prev => prev.filter(w => w.speciesId !== speciesId));
  };

  const handleSubmit = () => {
    const dive: Omit<DiveLog, 'id'> = {
      siteId: formData.siteId,
      date: formData.date,
      startTime: formData.startTime,
      endTime: formData.endTime,
      maxDepth: parseFloat(formData.maxDepth) || 0,
      averageDepth: parseFloat(formData.averageDepth) || undefined,
      bottomTime: parseInt(formData.bottomTime) || 0,
      startPressure: parseInt(formData.startPressure) || 200,
      endPressure: parseInt(formData.endPressure) || 0,
      temperature: parseFloat(formData.temperature) || 0,
      visibility: parseFloat(formData.visibility) || 0,
      current: formData.current,
      conditions: formData.conditions,
      wildlife: selectedWildlife,
      notes: formData.notes,
      instructorName: formData.instructorName || undefined,
      instructorNumber: formData.instructorNumber || undefined,
      signed: false,
      equipment: {
        wetsuit: formData.equipment.wetsuit,
        tank: formData.equipment.tank,
        weights: parseFloat(formData.equipment.weights) || 0
      }
    };

    onSave(dive);
  };

  const prefillFromSite = () => {
    if (selectedSite) {
      setFormData(prev => ({
        ...prev,
        temperature: selectedSite.averageTemp.toString(),
        visibility: selectedSite.averageVisibility.toString()
      }));
    }
  };

  return (
    <div className="max-w-2xl mx-auto p-4 space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Button variant="ghost" size="sm" onClick={onBack}>
          <ArrowLeft className="w-4 h-4" />
        </Button>
        <div>
          <h1 className="text-2xl font-bold">Log New Dive</h1>
          <p className="text-muted-foreground">Step {currentStep} of 4</p>
        </div>
      </div>

      {/* Progress Bar */}
      <div className="w-full bg-muted rounded-full h-2">
        <div 
          className="bg-blue-600 h-2 rounded-full transition-all duration-300"
          style={{ width: `${(currentStep / 4) * 100}%` }}
        />
      </div>

      {/* Step 1: Site & Basic Info */}
      {currentStep === 1 && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <MapPin className="w-5 h-5 text-blue-600" />
              Dive Site & Timing
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <Label htmlFor="site">Dive Site</Label>
              <Select value={formData.siteId} onValueChange={(value) => setFormData(prev => ({ ...prev, siteId: value }))}>
                <SelectTrigger>
                  <SelectValue placeholder="Select a dive site" />
                </SelectTrigger>
                <SelectContent>
                  {sites.map(site => (
                    <SelectItem key={site.id} value={site.id}>
                      <div>
                        <p>{site.name}</p>
                        <p className="text-sm text-muted-foreground">{site.location}</p>
                      </div>
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              {selectedSite && (
                <div className="mt-2 p-3 bg-muted rounded-lg">
                  <p className="text-sm">{selectedSite.description}</p>
                  <div className="flex gap-4 mt-2 text-sm text-muted-foreground">
                    <span>Avg Temp: {selectedSite.averageTemp}°C</span>
                    <span>Avg Vis: {selectedSite.averageVisibility}m</span>
                    <span>Max Depth: {selectedSite.maxDepth}m</span>
                  </div>
                  <Button variant="outline" size="sm" className="mt-2" onClick={prefillFromSite}>
                    Use Site Defaults
                  </Button>
                </div>
              )}
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label htmlFor="date">Date</Label>
                <Input
                  type="date"
                  value={formData.date}
                  onChange={(e) => setFormData(prev => ({ ...prev, date: e.target.value }))}
                />
              </div>
              <div>
                <Label htmlFor="startTime">Start Time</Label>
                <Input
                  type="time"
                  value={formData.startTime}
                  onChange={(e) => setFormData(prev => ({ ...prev, startTime: e.target.value }))}
                />
              </div>
            </div>

            <Button onClick={() => setCurrentStep(2)} className="w-full">
              Continue
            </Button>
          </CardContent>
        </Card>
      )}

      {/* Step 2: Dive Metrics */}
      {currentStep === 2 && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Gauge className="w-5 h-5 text-blue-600" />
              Dive Metrics
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label htmlFor="maxDepth" className="flex items-center gap-2">
                  <Gauge className="w-4 h-4" />
                  Max Depth (m)
                </Label>
                <Input
                  type="number"
                  placeholder="18"
                  value={formData.maxDepth}
                  onChange={(e) => setFormData(prev => ({ ...prev, maxDepth: e.target.value }))}
                />
              </div>
              <div>
                <Label htmlFor="bottomTime" className="flex items-center gap-2">
                  <Clock className="w-4 h-4" />
                  Bottom Time (min)
                </Label>
                <Input
                  type="number"
                  placeholder="45"
                  value={formData.bottomTime}
                  onChange={(e) => setFormData(prev => ({ ...prev, bottomTime: e.target.value }))}
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label htmlFor="startPressure">Start Pressure (bar)</Label>
                <Input
                  type="number"
                  value={formData.startPressure}
                  onChange={(e) => setFormData(prev => ({ ...prev, startPressure: e.target.value }))}
                />
              </div>
              <div>
                <Label htmlFor="endPressure">End Pressure (bar)</Label>
                <Input
                  type="number"
                  placeholder="50"
                  value={formData.endPressure}
                  onChange={(e) => setFormData(prev => ({ ...prev, endPressure: e.target.value }))}
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label htmlFor="temperature" className="flex items-center gap-2">
                  <Thermometer className="w-4 h-4" />
                  Temperature (°C)
                </Label>
                <Input
                  type="number"
                  placeholder="26"
                  value={formData.temperature}
                  onChange={(e) => setFormData(prev => ({ ...prev, temperature: e.target.value }))}
                />
              </div>
              <div>
                <Label htmlFor="visibility" className="flex items-center gap-2">
                  <Eye className="w-4 h-4" />
                  Visibility (m)
                </Label>
                <Input
                  type="number"
                  placeholder="25"
                  value={formData.visibility}
                  onChange={(e) => setFormData(prev => ({ ...prev, visibility: e.target.value }))}
                />
              </div>
            </div>

            <div className="flex gap-4">
              <Button variant="outline" onClick={() => setCurrentStep(1)}>
                Back
              </Button>
              <Button onClick={() => setCurrentStep(3)} className="flex-1">
                Continue
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Step 3: Wildlife & Notes */}
      {currentStep === 3 && (
        <Card>
          <CardHeader>
            <CardTitle>Wildlife & Notes</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <Label>Wildlife Spotted</Label>
              <div className="grid grid-cols-2 gap-2 mt-2">
                {wildlife.slice(0, 6).map(species => (
                  <Button
                    key={species.id}
                    variant="outline"
                    size="sm"
                    onClick={() => addWildlifeSighting(species.id)}
                    className={selectedWildlife.some(w => w.speciesId === species.id) ? 'bg-blue-100 border-blue-300' : ''}
                  >
                    {species.name}
                  </Button>
                ))}
              </div>
              
              {selectedWildlife.length > 0 && (
                <div className="mt-3 space-y-2">
                  <p className="text-sm font-medium">Spotted:</p>
                  <div className="flex flex-wrap gap-2">
                    {selectedWildlife.map(sighting => {
                      const species = wildlife.find(w => w.id === sighting.speciesId);
                      return (
                        <Badge key={sighting.speciesId} variant="secondary" className="cursor-pointer" onClick={() => removeWildlifeSighting(sighting.speciesId)}>
                          {species?.name} ({sighting.count})
                        </Badge>
                      );
                    })}
                  </div>
                </div>
              )}
            </div>

            <div>
              <Label htmlFor="notes">Notes</Label>
              <div className="relative">
                <Textarea
                  placeholder="Describe your dive experience..."
                  value={formData.notes}
                  onChange={(e) => setFormData(prev => ({ ...prev, notes: e.target.value }))}
                  className="pr-12"
                />
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  className={`absolute top-2 right-2 ${isRecording ? 'text-red-500' : 'text-muted-foreground'}`}
                  onClick={handleVoiceInput}
                >
                  <Mic className={`w-4 h-4 ${isRecording ? 'animate-pulse' : ''}`} />
                </Button>
              </div>
              {isRecording && (
                <p className="text-sm text-red-500 mt-1">Recording... Speak now</p>
              )}
            </div>

            <div className="flex gap-4">
              <Button variant="outline" onClick={() => setCurrentStep(2)}>
                Back
              </Button>
              <Button onClick={() => setCurrentStep(4)} className="flex-1">
                Continue
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Step 4: Review & Save */}
      {currentStep === 4 && (
        <Card>
          <CardHeader>
            <CardTitle>Review & Save</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-3">
              <div className="flex justify-between">
                <span className="text-muted-foreground">Site:</span>
                <span>{selectedSite?.name || 'Unknown'}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Date:</span>
                <span>{formData.date}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Max Depth:</span>
                <span>{formData.maxDepth}m</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Bottom Time:</span>
                <span>{formData.bottomTime} minutes</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Temperature:</span>
                <span>{formData.temperature}°C</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Visibility:</span>
                <span>{formData.visibility}m</span>
              </div>
              {selectedWildlife.length > 0 && (
                <div>
                  <span className="text-muted-foreground">Wildlife:</span>
                  <div className="flex flex-wrap gap-1 mt-1">
                    {selectedWildlife.map(sighting => {
                      const species = wildlife.find(w => w.id === sighting.speciesId);
                      return (
                        <Badge key={sighting.speciesId} variant="outline" className="text-xs">
                          {species?.name} ({sighting.count})
                        </Badge>
                      );
                    })}
                  </div>
                </div>
              )}
            </div>

            <div className="flex gap-4">
              <Button variant="outline" onClick={() => setCurrentStep(3)}>
                Back
              </Button>
              <Button onClick={handleSubmit} className="flex-1 bg-green-600 hover:bg-green-700">
                Save Dive Log
              </Button>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}