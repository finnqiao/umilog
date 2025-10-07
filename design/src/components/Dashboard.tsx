import React from 'react';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { Badge } from './ui/badge';
import { Button } from './ui/button';
import { MapPin, Plus, Calendar, BarChart3, Fish, Award } from 'lucide-react';
import { DiveLog, UserStats } from '../types';
import { ImageWithFallback } from './figma/ImageWithFallback';

interface DashboardProps {
  recentDives: DiveLog[];
  userStats: UserStats;
  onStartNewDive: () => void;
  onViewAllDives: () => void;
  onViewMap: () => void;
}

export function Dashboard({ recentDives, userStats, onStartNewDive, onViewAllDives, onViewMap }: DashboardProps) {
  return (
    <div className="space-y-6 p-4">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-primary">UmiLog</h1>
          <p className="text-muted-foreground">Your dive adventures await</p>
        </div>
        <Button 
          onClick={onStartNewDive}
          size="lg"
          className="bg-blue-600 hover:bg-blue-700 text-white shadow-lg"
        >
          <Plus className="w-5 h-5 mr-2" />
          Log Dive
        </Button>
      </div>

      {/* Quick Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="p-4 text-center">
            <div className="text-2xl font-bold text-blue-600">{userStats.totalDives}</div>
            <p className="text-sm text-muted-foreground">Total Dives</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <div className="text-2xl font-bold text-teal-600">{userStats.maxDepth}m</div>
            <p className="text-sm text-muted-foreground">Max Depth</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <div className="text-2xl font-bold text-green-600">{userStats.sitesVisited}</div>
            <p className="text-sm text-muted-foreground">Sites Visited</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <div className="text-2xl font-bold text-purple-600">{userStats.speciesSpotted}</div>
            <p className="text-sm text-muted-foreground">Species Spotted</p>
          </CardContent>
        </Card>
      </div>

      {/* Hero Map Card */}
      <Card className="overflow-hidden">
        <div className="relative h-48">
          <ImageWithFallback 
            src="https://images.unsplash.com/photo-1713098965471-d324f294a71d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx3b3JsZCUyMG1hcCUyMGRpdmluZyUyMGxvY2F0aW9uc3xlbnwxfHx8fDE3NTk4MjAxNDJ8MA&ixlib=rb-4.1.0&q=80&w=1080&utm_source=figma&utm_medium=referral"
            alt="World diving locations map"
            className="w-full h-full object-cover"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent" />
          <div className="absolute bottom-4 left-4 text-white">
            <h3 className="text-xl font-semibold">Explore Dive Sites</h3>
            <p className="text-sm opacity-90">{userStats.sitesVisited} sites visited • Discover more</p>
          </div>
          <Button 
            onClick={onViewMap}
            variant="secondary" 
            size="sm"
            className="absolute bottom-4 right-4"
          >
            <MapPin className="w-4 h-4 mr-2" />
            View Map
          </Button>
        </div>
      </Card>

      {/* Recent Dives */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-4">
          <CardTitle className="flex items-center gap-2">
            <Calendar className="w-5 h-5 text-blue-600" />
            Recent Dives
          </CardTitle>
          <Button variant="outline" size="sm" onClick={onViewAllDives}>
            View All
          </Button>
        </CardHeader>
        <CardContent className="space-y-4">
          {recentDives.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground">
              <Fish className="w-12 h-12 mx-auto mb-4 opacity-50" />
              <p>No dives logged yet</p>
              <p className="text-sm">Start your diving journey by logging your first dive!</p>
            </div>
          ) : (
            recentDives.slice(0, 3).map((dive) => (
              <div key={dive.id} className="flex items-center space-x-4 p-3 border rounded-lg hover:bg-accent/50 transition-colors">
                <div className="flex-shrink-0">
                  <div className="w-12 h-12 bg-blue-100 dark:bg-blue-900 rounded-full flex items-center justify-center">
                    <Fish className="w-6 h-6 text-blue-600" />
                  </div>
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <p className="font-medium">Dive #{dive.id}</p>
                    {dive.signed && (
                      <Badge variant="secondary" className="text-xs">
                        <Award className="w-3 h-3 mr-1" />
                        Signed
                      </Badge>
                    )}
                  </div>
                  <p className="text-sm text-muted-foreground">{dive.date} • {dive.maxDepth}m • {dive.bottomTime}min</p>
                  <p className="text-sm text-muted-foreground truncate">{dive.notes}</p>
                </div>
                <div className="text-right text-sm text-muted-foreground">
                  <div className="flex items-center gap-1">
                    <MapPin className="w-3 h-3" />
                    Site #{dive.siteId}
                  </div>
                </div>
              </div>
            ))
          )}
        </CardContent>
      </Card>

      {/* Quick Actions */}
      <div className="grid grid-cols-2 gap-4">
        <Card className="hover:shadow-md transition-shadow cursor-pointer" onClick={onViewMap}>
          <CardContent className="p-6 text-center">
            <MapPin className="w-8 h-8 mx-auto mb-3 text-blue-600" />
            <h3 className="font-medium mb-1">Site Explorer</h3>
            <p className="text-sm text-muted-foreground">Find new dive sites</p>
          </CardContent>
        </Card>
        <Card className="hover:shadow-md transition-shadow cursor-pointer">
          <CardContent className="p-6 text-center">
            <BarChart3 className="w-8 h-8 mx-auto mb-3 text-green-600" />
            <h3 className="font-medium mb-1">Statistics</h3>
            <p className="text-sm text-muted-foreground">View your progress</p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}