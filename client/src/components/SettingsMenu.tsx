import { Settings as SettingsIcon, LogOut, User as UserIcon, Activity, Globe, CheckCircle2, XCircle, LayoutTemplate } from "lucide-react";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
  PopoverHeader,
  PopoverTitle,
} from "@/components/ui/popover";
import { LanguageSwitcher } from "./LanguageSwitcher";
import { useAuth } from "@/contexts/AuthContext";
import { useTranslation } from "@/i18n";
import { useSettingsStore } from "@/stores/settings";

function ConnectionTest() {
  const { t } = useTranslation();
  const [status, setStatus] = useState<"idle" | "loading" | "success" | "error">("idle");
  const [debugData, setDebugData] = useState<any>(null);

  const testConnection = async () => {
    setStatus("loading");
    const start = Date.now();
    try {
      const res = await fetch("/api/health");
      const latency = Date.now() - start;
      const data = await res.json();
      setDebugData({
        latency: `${latency}ms`,
        status: res.status,
        endpoint: window.location.origin + "/api/health",
        serverStatus: data.status
      });
      setStatus("success");
    } catch (err: any) {
      setDebugData({
        error: err.message,
        endpoint: window.location.origin + "/api/health"
      });
      setStatus("error");
    }
  };

  return (
    <div className="space-y-2 mt-2">
      <Button 
        variant="outline" 
        size="sm" 
        onClick={testConnection} 
        disabled={status === "loading"}
        className="w-full h-8 text-[11px]"
      >
        <Activity className={`h-3 w-3 mr-2 ${status === "loading" ? "animate-spin" : ""}`} />
        {status === "loading" ? t("common.loading") : "Проверить связь"}
      </Button>
      
      {status !== "idle" && (
        <div className="bg-muted/50 rounded p-2 text-[10px] font-mono space-y-1">
          {status === "success" ? (
            <div className="text-green-500 flex items-center gap-1 mb-1">
              <CheckCircle2 className="h-3 w-3" /> OK
            </div>
          ) : status === "error" ? (
            <div className="text-red-500 flex items-center gap-1 mb-1">
              <XCircle className="h-3 w-3" /> Error
            </div>
          ) : null}
          {debugData && Object.entries(debugData).map(([key, val]) => (
            <div key={key} className="flex justify-between">
              <span className="text-muted-foreground">{key}:</span>
              <span className="truncate ml-2">{String(val)}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export function SettingsMenu() {
  const { user, logout } = useAuth();
  const { t } = useTranslation();
  const squareCovers = useSettingsStore(s => s.squareCovers);
  const setSquareCovers = useSettingsStore(s => s.setSquareCovers);

  return (
    <Popover>
      <PopoverTrigger asChild>
        <Button variant="ghost" size="icon" className="text-muted-foreground hover:text-foreground">
          <SettingsIcon className="h-5 w-5" />
        </Button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-72 p-0 overflow-hidden border-border bg-popover/95 backdrop-blur-md">
        <PopoverHeader className="px-4 py-3 border-b bg-muted/20">
          <PopoverTitle className="text-sm font-bold tracking-tight">{t("settings.title")}</PopoverTitle>
        </PopoverHeader>
        
        <div className="flex flex-col">
          {/* Account Section */}
          <div className="px-4 py-4 border-b">
            <h3 className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground/70 mb-2.5 flex items-center gap-1.5">
              <UserIcon className="h-3 w-3" />
              {t("settings.account")}
            </h3>
            <div className="flex flex-col gap-1">
              <p className="text-[10px] text-muted-foreground leading-none">{t("settings.loggedInAs")}</p>
              <p className="text-sm font-semibold truncate leading-tight">{user?.email}</p>
            </div>
          </div>

          <div className="p-1 space-y-0.5">
            {/* Language Selection */}
            <div className="flex items-center justify-between px-3 py-2 text-sm rounded-md transition-colors">
              <span className="text-muted-foreground font-medium">Язык / Language</span>
              <LanguageSwitcher />
            </div>

            <div className="h-px bg-border/50 mx-2 my-1" />

            {/* Appearance Section */}
            <div className="px-4 py-2">
              <h3 className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground/70 mb-2 flex items-center gap-1.5">
                <LayoutTemplate className="h-3 w-3" />
                {t("settings.appearance")}
              </h3>
              <div className="flex items-center justify-between">
                <span className="text-xs">{t("settings.squareCovers")}</span>
                <Button 
                  variant={squareCovers ? "default" : "outline"} 
                  size="sm"
                  className="h-7 px-3 text-[10px]"
                  onClick={() => setSquareCovers(!squareCovers)}
                >
                  {squareCovers ? "ON" : "OFF"}
                </Button>
              </div>
            </div>

            <div className="h-px bg-border/50 mx-2 my-1" />

            {/* Network Section */}
            <div className="px-4 py-2">
              <h3 className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground/70 mb-2 flex items-center gap-1.5">
                <Globe className="h-3 w-3" />
                Сеть
              </h3>
              <ConnectionTest />
            </div>

            {/* Logout Button */}
            <Button 
              variant="ghost" 
              onClick={logout} 
              className="w-full justify-start gap-2.5 text-red-500 hover:text-red-600 hover:bg-red-500/10 h-10 px-3 rounded-md mx-0"
            >
              <LogOut className="h-4 w-4" />
              <span className="font-medium text-sm">{t("auth.logout")}</span>
            </Button>
          </div>
        </div>
      </PopoverContent>
    </Popover>
  );
}
