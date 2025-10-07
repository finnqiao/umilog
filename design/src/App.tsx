import React, { useState, useEffect } from 'react';
import { Dashboard } from './components/Dashboard';
import { DiveLogger } from './components/DiveLogger';
import { DiveHistory } from './components/DiveHistory';
import { SiteExplorer } from './components/SiteExplorer';
import { BackfillWizard } from './components/BackfillWizard';
import { useLocalStorage } from './hooks/useLocalStorage';
import { mockSites, mockWildlife, mockDiveLogs, mockUserStats } from './data/mockData';
import { DiveLog, DiveSite, WildlifeSpecies, UserStats } from './types';
import { Toaster } from './components/ui/sonner';
import { toast } from "sonner@2.0.3";
import { Home, Plus, History, Map, MoreHorizontal } from 'lucide-react';

type AppView = 'home' | 'log' | 'history' | 'sites' | 'more';

export default function App() {
  // Local storage state
  const [dives, setDives] = useLocalStorage<DiveLog[]>('umilog-dives', mockDiveLogs);
  const [sites, setSites] = useLocalStorage<DiveSite[]>('umilog-sites', mockSites);
  const [wildlife, setWildlife] = useLocalStorage<WildlifeSpecies[]>('umilog-wildlife', mockWildlife);
  const [userStats, setUserStats] = useLocalStorage<UserStats>('umilog-stats', mockUserStats);
  
  // UI state
  const [currentView, setCurrentView] = useState<AppView>('home');
  const [selectedSiteId, setSelectedSiteId] = useState<string | undefined>();
  const [showBackfill, setShowBackfill] = useState(false);

  // Calculate user stats from actual data
  useEffect(() => {
    const visitedSiteIds = Array.from(new Set(dives.map(dive => dive.siteId)));
    const totalBottomTime = dives.reduce((sum, dive) => sum + dive.bottomTime, 0);
    const maxDepth = dives.length > 0 ? Math.max(...dives.map(dive => dive.maxDepth)) : 0;
    const allWildlife = dives.flatMap(dive => dive.wildlife);
    const speciesSpotted = Array.from(new Set(allWildlife.map(w => w.speciesId))).length;

    setUserStats(prev => ({
      ...prev,
      totalDives: dives.length,
      totalBottomTime,
      maxDepth,
      sitesVisited: visitedSiteIds.length,
      speciesSpotted
    }));
  }, [dives]);

  const handleSaveDive = (newDive: Omit<DiveLog, 'id'>) => {
    const dive: DiveLog = {
      ...newDive,
      id: Date.now().toString()
    };
    
    setDives(prev => [dive, ...prev]);
    setCurrentView('home');
    toast.success('Dive logged successfully!', {
      description: `${dive.maxDepth}m dive at site ${dive.siteId}`
    });
  };

  const handleSaveBackfillDives = (newDives: Omit<DiveLog, 'id'>[]) => {
    const divesWithIds: DiveLog[] = newDives.map(dive => ({
      ...dive,
      id: Date.now().toString() + Math.random().toString(36).substr(2, 9)
    }));
    
    setDives(prev => [...divesWithIds, ...prev]);
    setShowBackfill(false);
    setCurrentView('home');
    toast.success(`${newDives.length} dives added successfully!`, {
      description: 'Your dive history has been updated'
    });
  };

  const handleSelectSite = (siteId: string) => {
    setSelectedSiteId(siteId);
    setCurrentView('log');
  };

  const handleExportData = () => {
    const exportData = {
      dives,
      sites,
      userStats,
      exportDate: new Date().toISOString()
    };
    
    const dataStr = JSON.stringify(exportData, null, 2);
    const dataBlob = new Blob([dataStr], { type: 'application/json' });
    const url = URL.createObjectURL(dataBlob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `umilog-export-${new Date().toISOString().split('T')[0]}.json`;
    link.click();
    
    toast.success('Data exported successfully!', {
      description: 'Your dive logs have been downloaded as JSON'
    });
  };

  const visitedSiteIds = Array.from(new Set(dives.map(dive => dive.siteId)));

  const renderCurrentView = () => {
    if (showBackfill) {
      return (
        <BackfillWizard
          sites={sites}
          onSave={handleSaveBackfillDives}
          onBack={() => setShowBackfill(false)}
        />
      );
    }

    switch (currentView) {
      case 'home':
        return (
          <Dashboard
            recentDives={dives.slice(0, 5)}
            userStats={userStats}
            onStartNewDive={() => setCurrentView('log')}
            onViewAllDives={() => setCurrentView('history')}
            onViewMap={() => setCurrentView('sites')}
          />
        );
      case 'log':
        return (
          <DiveLogger
            sites={sites}
            wildlife={wildlife}
            selectedSiteId={selectedSiteId}
            onSave={handleSaveDive}
            onBack={() => {
              setSelectedSiteId(undefined);
              setCurrentView('home');
            }}
          />
        );
      case 'history':
        return (
          <DiveHistory
            dives={dives}
            sites={sites}
            wildlife={wildlife}
            onBack={() => setCurrentView('home')}
            onExport={handleExportData}
          />
        );
      case 'sites':
        return (
          <SiteExplorer
            sites={sites}
            visitedSiteIds={visitedSiteIds}
            onBack={() => setCurrentView('home')}
            onSelectSite={handleSelectSite}
            onAddNewSite={() => toast.info('Add new site feature coming soon!')}
          />
        );
      case 'more':
        return (
          <div className="flex-1 bg-background">
            <div className="p-6 space-y-6">
              <div className="flex items-center justify-between">
                <h1>More</h1>
                <button
                  onClick={() => setCurrentView('home')}
                  className="p-2 hover:bg-muted rounded-lg transition-colors"
                >
                  <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              <div className="space-y-4">
                <button
                  onClick={() => setShowBackfill(true)}
                  className="w-full p-4 bg-card rounded-xl border border-border flex items-center justify-between hover:bg-muted/50 transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-blue-100 dark:bg-blue-900/30 rounded-lg flex items-center justify-center">
                      <Plus className="w-5 h-5 text-blue-600 dark:text-blue-400" />
                    </div>
                    <div className="text-left">
                      <h3>Backfill Past Dives</h3>
                      <p className="text-muted-foreground">Add multiple dives quickly</p>
                    </div>
                  </div>
                  <svg className="w-5 h-5 text-muted-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                  </svg>
                </button>

                <button
                  onClick={handleExportData}
                  className="w-full p-4 bg-card rounded-xl border border-border flex items-center justify-between hover:bg-muted/50 transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-green-100 dark:bg-green-900/30 rounded-lg flex items-center justify-center">
                      <svg className="w-5 h-5 text-green-600 dark:text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                      </svg>
                    </div>
                    <div className="text-left">
                      <h3>Export Data</h3>
                      <p className="text-muted-foreground">Download your dive logs</p>
                    </div>
                  </div>
                  <svg className="w-5 h-5 text-muted-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                  </svg>
                </button>

                <div className="p-4 bg-muted rounded-xl">
                  <h3 className="mb-2">Statistics</h3>
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <p className="text-muted-foreground">Total Dives</p>
                      <p>{userStats.totalDives}</p>
                    </div>
                    <div>
                      <p className="text-muted-foreground">Max Depth</p>
                      <p>{userStats.maxDepth}m</p>
                    </div>
                    <div>
                      <p className="text-muted-foreground">Sites Visited</p>
                      <p>{userStats.sitesVisited}</p>
                    </div>
                    <div>
                      <p className="text-muted-foreground">Species Spotted</p>
                      <p>{userStats.speciesSpotted}</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        );
      default:
        return null;
    }
  };

  return (
    <div className="min-h-screen bg-background flex flex-col">
      {/* Main Content */}
      <div className="flex-1 pb-20">
        {renderCurrentView()}
      </div>

      {/* iOS Bottom Tab Navigation */}
      {!showBackfill && (
        <div className="fixed bottom-0 left-0 right-0 bg-background border-t border-border">
          <div className="flex items-center justify-around px-2 py-2 safe-area-pb">
            <button
              onClick={() => setCurrentView('home')}
              className={`flex flex-col items-center gap-1 p-2 min-w-0 ${
                currentView === 'home' ? 'text-blue-600' : 'text-muted-foreground'
              }`}
            >
              <Home className="w-6 h-6" />
              <span className="text-xs">Home</span>
            </button>

            <button
              onClick={() => setCurrentView('history')}
              className={`flex flex-col items-center gap-1 p-2 min-w-0 ${
                currentView === 'history' ? 'text-blue-600' : 'text-muted-foreground'
              }`}
            >
              <History className="w-6 h-6" />
              <span className="text-xs">History</span>
            </button>

            {/* Primary Log Button - Prominently Featured */}
            <button
              onClick={() => setCurrentView('log')}
              className={`flex flex-col items-center gap-1 p-2 min-w-0 ${
                currentView === 'log'
                  ? 'text-white'
                  : 'text-white'
              }`}
            >
              <div className={`w-12 h-12 rounded-full flex items-center justify-center ${
                currentView === 'log' ? 'bg-blue-700' : 'bg-blue-600'
              } shadow-lg`}>
                <Plus className="w-7 h-7" />
              </div>
              <span className="text-xs text-blue-600">Log</span>
            </button>

            <button
              onClick={() => setCurrentView('sites')}
              className={`flex flex-col items-center gap-1 p-2 min-w-0 ${
                currentView === 'sites' ? 'text-blue-600' : 'text-muted-foreground'
              }`}
            >
              <Map className="w-6 h-6" />
              <span className="text-xs">Sites</span>
            </button>

            <button
              onClick={() => setCurrentView('more')}
              className={`flex flex-col items-center gap-1 p-2 min-w-0 ${
                currentView === 'more' ? 'text-blue-600' : 'text-muted-foreground'
              }`}
            >
              <MoreHorizontal className="w-6 h-6" />
              <span className="text-xs">More</span>
            </button>
          </div>
        </div>
      )}

      <Toaster richColors position="top-center" />
    </div>
  );
}