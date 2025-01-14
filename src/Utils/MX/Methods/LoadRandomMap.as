namespace MX
{
    void LoadRandomMap()
    {
        try
        {
            if (TM::CurrentTitlePack() == "") {
                Log::Warn("Please load a title pack first.", true);
                return;
            }
            RandomMapIsLoading = true;
            string URL = CreateQueryURL();
            Json::Value res = API::GetAsync(URL)["results"][0];
            Log::Trace("RandomMapRes: "+Json::Write(res));

            Json::Value playedAt = Json::Object();
            Time::Info date = Time::Parse();
            playedAt["Year"] = date.Year;
            playedAt["Month"] = date.Month;
            playedAt["Day"] = date.Day;
            playedAt["Hour"] = date.Hour;
            playedAt["Minute"] = date.Minute;
            playedAt["Second"] = date.Second;
            res["PlayedAt"] = playedAt;

            MX::MapInfo@ map = MX::MapInfo(res);

            if (map is null){
                Log::Warn("Map is null, retrying...");
                LoadRandomMap();
                return;
            }

            Log::LoadingMapNotification(map);

            // Save the recently played map json
            // Method: Creates a new Array to save first the new map, then the old ones.
            Json::Value arr = Json::Array();
            arr.Add(map.ToJson());
            if (DataJson["recentlyPlayed"].Length > 0) {
                for (uint i = 0; i < DataJson["recentlyPlayed"].Length; i++) {
                    arr.Add(DataJson["recentlyPlayed"][i]);
                }
            }
            // Resize the array to the max amount of maps (50, to not overload the json)
            if (arr.Length > 50) {
                for (uint i = 50; i < arr.Length; i++) {
                    arr.Remove(i);
                }
            }
            DataJson["recentlyPlayed"] = arr;
            DataManager::SaveData();

            RandomMapIsLoading = false;
            if (PluginSettings::closeOverlayOnMapLoaded) UI::HideOverlay();

#if TMNEXT
            TM::ClosePauseMenu();
#endif

            CTrackMania@ app = cast<CTrackMania>(GetApp());
            app.BackToMainMenu(); // If we're on a map, go back to the main menu else we'll get stuck on the current map
            while(!app.ManiaTitleControlScriptAPI.IsReady) {
                yield(); // Wait until the ManiaTitleControlScriptAPI is ready for loading the next map
            }

#if DEPENDENCY_CHAOSMODE
            if (ChaosMode::IsInRMCMode()) {
                Log::Trace("Loading map in Chaos Mode");
                app.ManiaTitleControlScriptAPI.PlayMap("https://"+MX_URL+"/maps/download/"+map.TrackID, "TrackMania/ChaosModeRMC", "");
            } else
#endif
            app.ManiaTitleControlScriptAPI.PlayMap("https://"+MX_URL+"/maps/download/"+map.TrackID, "", "");
        }
        catch
        {
            Log::Warn("Error while loading map ");
            Log::Error(MX_NAME + " API is not responding, it might be down.", true);
            APIDown = true;
            RandomMapIsLoading = false;
        }
    }

    string CreateQueryURL()
    {
        string url = "https://"+MX_URL+"/mapsearch2/search?api=on&random=1";

        if (RMC::IsRunning)
        {
#if TMNEXT
            url += "&etags=23,37,40";
#else
            url += "&etags=20";
#endif
            url += "&lengthop=1";
            url += "&length=9";
        }
        else
        {
            if (PluginSettings::MapLengthOperator != "Exacts"){
                url += "&lengthop=" + PluginSettings::SearchingMapLengthOperators.Find(PluginSettings::MapLengthOperator);
            }
            if (PluginSettings::MapLength != "Anything"){
                url += "&length=" + (PluginSettings::SearchingMapLengths.Find(PluginSettings::MapLength)-1);
            }
            if (PluginSettings::MapTag != "Anything"){
                url += "&tags=" + PluginSettings::MapTagID;
            }
            if (PluginSettings::ExcludeMapTag != "Nothing"){
                url += "&etags=" + PluginSettings::ExcludeMapTagID;
            }
        }

#if TMNEXT
            // prevent loading CharacterPilot maps
            url += "&vehicles=1";
#elif MP4
            // Fetch in the correct titlepack
            if (TM::CurrentTitlePack() == "TMAll") {
                url += "&tpack=" + TM::CurrentTitlePack()+"&tpack=TMCanyon&tpack=TMValley&tpack=TMStadium&tpack=TMLagoon";
            } else {
                url += "&tpack=" + TM::CurrentTitlePack();
            }
#endif

        // prevent loading non-Race maps (Royal, flagrush etc...)
        url += "&mtype="+SUPPORTED_MAP_TYPE;

        return url;
    }
}