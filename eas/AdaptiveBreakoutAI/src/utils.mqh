// CORRECTED
#pragma once

class Utils 
{
public:
    static datetime lastTradeTime;

    static bool IsWithinSession(int startHour, int endHour) { /* ... implementation ... */ return true; }

    static void StampTradeTime() { lastTradeTime = TimeCurrent(); }
    
    static bool PassedCooldownMinutes(int minutes) {
        if (lastTradeTime == 0) return true;
        return (TimeCurrent() - lastTradeTime) >= (minutes * 60);
    }

    static int ReadAISignal(string filename) {
        int file_handle = FileOpen(filename, FILE_READ | FILE_TXT);
        if (file_handle == INVALID_HANDLE) return 0;

        string line; // DECLARE THE VARIABLE
        if (!FileIsEnding(file_handle)) {
            line = FileReadString(file_handle);
        }
        FileClose(file_handle);
        
        return (int)StringToInteger(line);
    }
};
// Initialize static member
datetime Utils::lastTradeTime = 0;
