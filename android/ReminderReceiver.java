package tz.altra.pharmacy;

import android.Manifest;
import android.app.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.os.Build;
import org.json.*;
import java.util.*;

public final class ReminderReceiver extends BroadcastReceiver {
    private static final String CHANNEL="pharmacy-reminders";
    private static PendingIntent alarm(Context c,String id){Intent i=new Intent(c,ReminderReceiver.class).setAction("tz.altra.pharmacy.REMINDER").setData(android.net.Uri.parse("altra://reminder/"+id));return PendingIntent.getBroadcast(c,0,i,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);}
    static void cancel(Context c,String id){c.getSystemService(AlarmManager.class).cancel(alarm(c,id));c.getSystemService(NotificationManager.class).cancel(id,0);}
    static void schedule(Context c,JSONObject r){
        String id=r.optString("id");AlarmManager am=c.getSystemService(AlarmManager.class);PendingIntent pending=alarm(c,id);am.cancel(pending);
        try{Calendar due=MainActivity.calendar();due.setTime(MainActivity.date().parse(r.optString("due")));due.set(Calendar.HOUR_OF_DAY,9);long t=due.getTimeInMillis();if(t>System.currentTimeMillis())am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,t,pending);}catch(java.text.ParseException ignored){}
    }
    static void ensureChannel(Context c){if(Build.VERSION.SDK_INT>=26)c.getSystemService(NotificationManager.class).createNotificationChannel(new NotificationChannel(CHANNEL,"Pharmacy reminders",NotificationManager.IMPORTANCE_DEFAULT));}
    private JSONArray rows(Context c)throws JSONException{return new JSONObject(c.getSharedPreferences("altra_native",Context.MODE_PRIVATE).getString("records","{}")).optJSONArray("Reminders");}
    @Override public void onReceive(Context c,Intent intent){
        try{
            JSONArray a=rows(c);if(a==null)return;
            if(Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())){for(int i=0;i<a.length();i++)schedule(c,a.getJSONObject(i));return;}
            if(intent.getData()==null)return;String id=intent.getData().getLastPathSegment();boolean exists=false;for(int i=0;i<a.length();i++)if(a.getJSONObject(i).optString("id").equals(id))exists=true;if(!exists)return;
            if(Build.VERSION.SDK_INT>=33&&c.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)return;
            NotificationManager nm=c.getSystemService(NotificationManager.class);
            ensureChannel(c);
            Notification.Builder b=Build.VERSION.SDK_INT>=26?new Notification.Builder(c,CHANNEL):new Notification.Builder(c);
            PendingIntent open=PendingIntent.getActivity(c,0,new Intent(c,MainActivity.class),PendingIntent.FLAG_IMMUTABLE);
            nm.notify(id,0,b.setSmallIcon(android.R.drawable.ic_popup_reminder).setContentTitle("Altra Pharmacy reminder").setContentText("Unlock Altra to view your reminders.").setVisibility(Notification.VISIBILITY_PRIVATE).setContentIntent(open).setAutoCancel(true).build());
        }catch(JSONException ignored){}
    }
}
