// eas/AdaptiveBreakoutAI/src/utils.mqh

#ifndef UTILS_MQH
#define UTILS_MQH

class Utils {
private:
    static datetime m_last_trade_time;

public:
    // --- Session Time ---
    static bool IsWithinSession(int startHour, int endHour) {
        MqlDateTime time;
        TimeCurrent(time);
        return (time.hour >= startHour && time.hour <= endHour);
    }

    // --- Cooldown ---
    static void StampTradeTime() {
        m_last_trade_time = TimeCurrent();
    }

    static bool PassedCooldownMinutes(int minutes) {
        if (minutes <= 0) return true;
        return (TimeCurrent() - m_last_trade_time >= minutes * 60);
    }

    // --- AI Signal Reading ---
    static int ReadAISignal(string filename) {
        int handle = FileOpen(filename, FILE_READ | FILE_TXT);
        if (handle == INVALID_HANDLE) {
            Print("AI Signal file not found: ", filename);
            return 0; // Neutral signal if file not found
        }

        string content = FileReadString(handle);
        FileClose(handle);
        return (int)StringToInteger(content);
    }
};

// Initialize the static member variable outside the class
datetime Utils::m_last_trade_time = 0;

#endif // UTILS_MQH
