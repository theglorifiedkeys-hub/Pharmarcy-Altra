package tz.altra.pharmacy;

import android.Manifest;
import android.app.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.*;
import android.provider.Settings;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.io.*;
import java.text.*;
import java.util.*;

public final class MainActivity extends Activity {
    static final int GREEN=0xff175b44, INK=0xff172b24, BG=0xfff3f7f3, MINT=0xffe0f3e6;
    static final String[] PAGES={"Dawa","Clients","Suppliers","Reminders"};
    static final String[][] FIELDS={{"name","form","supplier","stock","expiry"},{"name","phone","notes"},{"name","location","phone"},{"title","due","category"}};
    private JSONObject data;
    private LinearLayout root, body;
    private int page=0;
    private boolean unlocked=false, authenticating=false;
    private long backgroundAt=0;
    private String pendingPhotoId;
    private android.content.SharedPreferences prefs;

    @Override public void onCreate(Bundle state){
        super.onCreate(state);
        getWindow().setStatusBarColor(GREEN); getWindow().setNavigationBarColor(GREEN);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
        prefs=getSharedPreferences("altra_native",MODE_PRIVATE);
        try{data=new JSONObject(prefs.getString("records","{}"));}catch(JSONException e){data=new JSONObject();}
        if(!data.has(PAGES[0])) seed();
        if(state!=null){pendingPhotoId=state.getString("photo");page=state.getInt("page");}
        render();
    }
    @Override protected void onSaveInstanceState(Bundle out){super.onSaveInstanceState(out);out.putString("photo",pendingPhotoId);out.putInt("page",page);}
    @Override protected void onStop(){super.onStop();if(unlocked)backgroundAt=SystemClock.elapsedRealtime();}
    @Override protected void onResume(){super.onResume();if(unlocked&&backgroundAt!=0&&SystemClock.elapsedRealtime()-backgroundAt>120000){unlocked=false;render();}backgroundAt=0;}
    private void seed(){
        add(0,new String[]{"Paracetamol 500 mg","Tablet","Dawa Distributors","240","2028-08-30"});
        add(0,new String[]{"Amoxicillin 250 mg","Capsule","MedSupply Tanzania","18","2028-05-10"});
        add(0,new String[]{"ORS Sachets","Sachet","Dawa Distributors","86","2028-10-15"});
        add(0,new String[]{"Vitamin C 1000 mg","Tablet","Afya Wholesale","9","2028-07-12"});
        add(1,new String[]{"Amina M.","+255 700 000 001","Sample returning client"});
        add(2,new String[]{"Dawa Distributors","Dar es Salaam","+255 700 000 011"});
        Calendar tomorrow=calendar(); tomorrow.add(Calendar.DATE,1);
        add(3,new String[]{"Review low stock",date().format(tomorrow.getTime()),"Inventory"});persist();
    }
    private JSONObject add(int p,String[] values){JSONObject r=new JSONObject();put(r,"id",UUID.randomUUID().toString());write(p,r,values);rows(p).put(r);return r;}
    private void write(int p,JSONObject r,String[] v){for(int i=0;i<v.length;i++)put(r,FIELDS[p][i],v[i]);}
    private JSONArray rows(int p){JSONArray a=data.optJSONArray(PAGES[p]);if(a==null){a=new JSONArray();put(data,PAGES[p],a);}return a;}
    private static void put(JSONObject obj,String key,Object val){try{obj.put(key,val);}catch(JSONException e){throw new IllegalArgumentException(e);}}
    private void persist(){prefs.edit().putString("records",data.toString()).apply();}
    private int dp(int n){return (int)(n*getResources().getDisplayMetrics().density+0.5f);}
    private GradientDrawable bg(int color,int radius){GradientDrawable b=new GradientDrawable();b.setColor(color);b.setCornerRadius(dp(radius));return b;}
    private TextView text(String value,int size,int color,boolean bold){TextView t=new TextView(this);t.setText(value);t.setTextSize(size);t.setTextColor(color);if(bold)t.setTypeface(null,Typeface.BOLD);return t;}
    private LinearLayout block(){LinearLayout l=new LinearLayout(this);l.setOrientation(LinearLayout.VERTICAL);return l;}
    private Button button(String label,boolean primary,Runnable action){Button b=new Button(this);b.setText(label);b.setAllCaps(false);b.setTextColor(primary?Color.WHITE:GREEN);b.setBackground(bg(primary?GREEN:MINT,12));b.setMinHeight(dp(46));b.setPadding(dp(12),dp(6),dp(12),dp(6));b.setOnClickListener(v->action.run());return b;}
    private void space(LinearLayout l,int h){l.addView(new View(this),new LinearLayout.LayoutParams(1,dp(h)));}
    private void message(String s){Toast.makeText(this,s,Toast.LENGTH_LONG).show();}
    private void render(){
        root=block();root.setBackgroundColor(BG);setContentView(root);
        LinearLayout head=block();head.setPadding(dp(18),dp(15),dp(18),dp(15));head.setBackgroundColor(GREEN);root.addView(head);
        head.addView(text("✚  Altra Pharmacy",24,Color.WHITE,true));head.addView(text("DAR ES SALAAM  •  OFFLINE WORKSPACE",11,0xffc7ebd6,true));
        ScrollView scroll=new ScrollView(this);root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));body=block();body.setPadding(dp(16),dp(16),dp(16),dp(24));scroll.addView(body);
        if(!unlocked){
            body.addView(text("Karibu, Altra team!",28,INK,true));space(body,8);
            body.addView(text("Unlock with your phone’s screen lock. Set a PIN, pattern, or password in Android Settings if you don’t have one yet.",15,INK,false));space(body,18);
            body.addView(button("Unlock workspace",true,this::unlock));space(body,8);
            body.addView(button("Android security settings",false,()->startActivity(new Intent(Settings.ACTION_SECURITY_SETTINGS))));return;
        }
        body.addView(text(PAGES[page],29,INK,true));space(body,6);
        body.addView(text(rows(page).length()+" records  •  Stored on this phone",13,GREEN,false));space(body,14);
        LinearLayout actions=new LinearLayout(this);body.addView(actions);
        int current=page;
        actions.addView(button("＋ Add record",true,()->editor(current,null)),new LinearLayout.LayoutParams(0,-2,1));
        if(page==0){spaceHorizontal(actions);actions.addView(button("Import CSV",false,this::chooseCsv),new LinearLayout.LayoutParams(0,-2,1));}
        if(page==3){spaceHorizontal(actions);actions.addView(button("Notifications",false,this::notificationSettings),new LinearLayout.LayoutParams(0,-2,1));}
        space(body,10);
        body.setAlpha(.82f);body.animate().alpha(1f).setDuration(160).start();
        EditText search=new EditText(this);search.setSingleLine(true);search.setTextSize(15);search.setHint("Search "+PAGES[page].toLowerCase(Locale.ROOT));body.addView(search);
        LinearLayout list=block();body.addView(list);showRows(list,"");
        search.addTextChangedListener(new android.text.TextWatcher(){public void beforeTextChanged(CharSequence s,int a,int c,int f){}public void onTextChanged(CharSequence s,int a,int b,int c){showRows(list,s.toString());}public void afterTextChanged(android.text.Editable e){}});
        LinearLayout tabs=new LinearLayout(this);tabs.setPadding(dp(6),dp(5),dp(6),dp(7));root.addView(tabs);
        for(int i=0;i<PAGES.length;i++){final int p=i;Button tab=button(PAGES[i],page==i,()->{page=p;render();});tab.setTextSize(11);tab.setPadding(0,0,0,0);tabs.addView(tab,new LinearLayout.LayoutParams(0,-2,1));if(i<3)spaceHorizontal(tabs);}
        Button lock=button("Lock",false,()->{unlocked=false;render();});lock.setTextSize(11);lock.setPadding(0,0,0,0);spaceHorizontal(tabs);tabs.addView(lock,new LinearLayout.LayoutParams(dp(48),-2));
    }
    private void spaceHorizontal(LinearLayout l){l.addView(new View(this),new LinearLayout.LayoutParams(dp(5),1));}
    private void showRows(LinearLayout list,String search){
        list.removeAllViews();JSONArray a=rows(page);int current=page;
        for(int i=0;i<a.length();i++){
            JSONObject r=a.optJSONObject(i);if(r==null||!r.toString().toLowerCase(Locale.ROOT).contains(search.toLowerCase(Locale.ROOT)))continue;
            LinearLayout card=block();card.setBackground(bg(Color.WHITE,15));card.setPadding(dp(14),dp(12),dp(14),dp(12));space(list,9);list.addView(card);
            card.addView(text(r.optString(FIELDS[page][0]),17,INK,true));space(card,4);
            String details;
            if(page==0){int qty=r.optInt("stock");String expiry=r.optString("expiry"), today=date().format(new Date());String status=expiry.compareTo(today)<0?"Expired":qty==0?"Out of stock":qty<20?"Low stock":"In stock";details=qty+" units  •  "+status+"\nExpires "+expiry+"  •  "+r.optString("supplier");}
            else details=r.optString(FIELDS[page][1])+"  •  "+r.optString(FIELDS[page][2]);
            card.addView(text(details,13,GREEN,false));card.setOnClickListener(v->editor(current,r));
            if(page==0&&photo(r.optString("id")).isFile()){ImageView im=new ImageView(this);im.setImageURI(android.net.Uri.fromFile(photo(r.optString("id"))));im.setScaleType(ImageView.ScaleType.CENTER_CROP);space(card,8);card.addView(im,new LinearLayout.LayoutParams(dp(100),dp(70)));}
        }
        if(list.getChildCount()==0){space(list,10);list.addView(text("No matching records.",14,GREEN,false));}
    }
    private void unlock(){
        KeyguardManager km=getSystemService(KeyguardManager.class);
        if(!km.isDeviceSecure()){message("Set up a screen lock in Android Settings first.");return;}
        Intent intent=km.createConfirmDeviceCredentialIntent("Unlock Altra Pharmacy","Confirm your Android screen lock");
        if(intent==null){message("Screen lock is unavailable.");return;}
        if(android.os.Build.VERSION.SDK_INT>=30){android.hardware.biometrics.BiometricManager bm=getSystemService(android.hardware.biometrics.BiometricManager.class);int authenticators=android.hardware.biometrics.BiometricManager.Authenticators.BIOMETRIC_STRONG|android.hardware.biometrics.BiometricManager.Authenticators.DEVICE_CREDENTIAL;if(bm.canAuthenticate(authenticators)==0){if(authenticating)return;authenticating=true;new android.hardware.biometrics.BiometricPrompt.Builder(this).setTitle("Unlock Altra Pharmacy").setAllowedAuthenticators(authenticators).build().authenticate(new CancellationSignal(),getMainExecutor(),new android.hardware.biometrics.BiometricPrompt.AuthenticationCallback(){@Override public void onAuthenticationSucceeded(android.hardware.biometrics.BiometricPrompt.AuthenticationResult result){authenticating=false;unlocked=true;render();scheduleAll();}@Override public void onAuthenticationError(int code,CharSequence error){authenticating=false;}});return;}}
        startActivityForResult(intent,10);
    }
    private void editor(int p,JSONObject record){
        ScrollView scroll=new ScrollView(this);LinearLayout f=block();f.setPadding(dp(18),dp(4),dp(18),dp(12));scroll.addView(f);EditText[] inputs=new EditText[FIELDS[p].length];
        for(int i=0;i<inputs.length;i++){String key=FIELDS[p][i];f.addView(text(key+(key.equals("expiry")||key.equals("due")?" (YYYY-MM-DD)":""),12,GREEN,true));EditText e=new EditText(this);inputs[i]=e;e.setTextSize(15);e.setSingleLine(true);if(key.equals("stock"))e.setInputType(android.text.InputType.TYPE_CLASS_NUMBER);if(record!=null)e.setText(record.optString(key));f.addView(e);}
        if(record!=null&&p==0){space(f,8);f.addView(button("Choose medicine photo",false,()->choosePhoto(record.optString("id"))));}
        AlertDialog.Builder b=new AlertDialog.Builder(this).setTitle((record==null?"Add · ":"Edit · ")+PAGES[p]).setView(scroll).setNegativeButton("Cancel",null).setPositiveButton("Save",null);
        if(record!=null)b.setNeutralButton(p==3?"Complete":"Delete",(d,w)->new AlertDialog.Builder(this).setMessage(p==3?"Mark this reminder complete?":"Delete this record?").setNegativeButton("Cancel",null).setPositiveButton("Confirm",(dd,ww)->{JSONArray a=rows(p);for(int i=0;i<a.length();i++)if(a.optJSONObject(i)==record){a.remove(i);break;}if(p==0)photo(record.optString("id")).delete();if(p==3)cancelReminder(record);persist();render();}).show());
        AlertDialog d=b.create();d.show();d.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(v->{String[] values=new String[inputs.length];for(int i=0;i<inputs.length;i++)values[i]=inputs[i].getText().toString().trim();try{validate(p,values);}catch(IllegalArgumentException e){message(e.getMessage());return;}JSONObject r=record;if(r==null)r=add(p,values);else write(p,r,values);persist();if(p==3){schedule(r);if(android.os.Build.VERSION.SDK_INT>=33&&checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS},20);}d.dismiss();render();});
    }
    static SimpleDateFormat date(){SimpleDateFormat d=new SimpleDateFormat("yyyy-MM-dd",Locale.ROOT);d.setTimeZone(TimeZone.getTimeZone("Africa/Dar_es_Salaam"));d.setLenient(false);return d;}
    static Calendar calendar(){return Calendar.getInstance(TimeZone.getTimeZone("Africa/Dar_es_Salaam"));}
    private static void validate(int p,String[] v){for(String s:v)if(s.isEmpty()||s.length()>500)throw new IllegalArgumentException("Fill each field (max 500 characters).");if(p==0){try{if(Integer.parseInt(v[3])<0)throw new NumberFormatException();}catch(NumberFormatException e){throw new IllegalArgumentException("Stock must be a non-negative whole number.");}}if(p==0||p==3){String s=v[p==0?4:1];try{if(!s.matches("[0-9]{4}-[0-9]{2}-[0-9]{2}"))throw new ParseException(s,0);date().parse(s);}catch(ParseException e){throw new IllegalArgumentException("Use a valid date in YYYY-MM-DD format.");}}}
    private void chooseCsv(){pick("text/*",11);}
    private void choosePhoto(String id){pendingPhotoId=id;pick("image/*",12);}
    private void pick(String mime,int code){Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType(mime);try{startActivityForResult(i,code);}catch(ActivityNotFoundException e){message("No file picker is available on this phone.");}}
    private File photo(String id){return new File(getFilesDir(),id+".jpg");}
    @Override protected void onActivityResult(int request,int result,Intent intent){
        super.onActivityResult(request,result,intent);
        if(result!=RESULT_OK)return;
        if(request==10){unlocked=true;render();scheduleAll();return;}
        if(!unlocked||intent==null||intent.getData()==null)return;
        final android.net.Uri uri=intent.getData();final String photoId=pendingPhotoId;
        new Thread(()->{try{
            if(request==11){byte[] bytes=readLimited(uri,1024*1024);List<String[]> records=Csv.parse(new String(bytes,java.nio.charset.StandardCharsets.UTF_8));for(String[] row:records)validate(0,row);runOnUiThread(()->{if(!unlocked||isFinishing()||isDestroyed())return;new AlertDialog.Builder(this).setTitle("Import medicine records").setMessage("Add "+records.size()+" new medicines? Existing records won’t be changed.").setNegativeButton("Cancel",null).setPositiveButton("Import",(d,w)->{for(String[] row:records)add(0,row);persist();render();message(records.size()+" medicines imported.");}).show();});}
            else if(request==12&&photoId!=null){byte[] bytes=readLimited(uri,16*1024*1024);android.graphics.BitmapFactory.Options options=new android.graphics.BitmapFactory.Options();options.inJustDecodeBounds=true;android.graphics.BitmapFactory.decodeByteArray(bytes,0,bytes.length,options);if(options.outWidth<=0||options.outHeight<=0)throw new IOException("This image format could not be read.");options.inJustDecodeBounds=false;options.inSampleSize=1;while(Math.max(options.outWidth,options.outHeight)/options.inSampleSize>720)options.inSampleSize*=2;android.graphics.Bitmap bitmap=android.graphics.BitmapFactory.decodeByteArray(bytes,0,bytes.length,options);if(bitmap==null)throw new IOException("This image format could not be read.");runOnUiThread(()->{try{if(!unlocked||isFinishing()||isDestroyed())return;boolean exists=false;JSONArray medicines=rows(0);for(int i=0;i<medicines.length();i++)if(photoId.equals(medicines.optJSONObject(i).optString("id")))exists=true;if(!exists)return;try(OutputStream out=new FileOutputStream(photo(photoId))){if(!bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG,85,out))throw new IOException();}render();message("Medicine photo saved.");}catch(IOException e){message("Could not save the photo.");}finally{bitmap.recycle();}});}
        }catch(IOException|IllegalArgumentException e){runOnUiThread(()->message(e.getMessage()==null?"Could not open the selected file.":e.getMessage()));}}).start();
    }
    private byte[] readLimited(android.net.Uri uri,int max)throws IOException{
        try(InputStream in=getContentResolver().openInputStream(uri);ByteArrayOutputStream out=new ByteArrayOutputStream()){
            if(in==null)throw new IOException("Could not open the selected file.");byte[] buffer=new byte[8192];int n;while((n=in.read(buffer))!=-1){if(out.size()+n>max)throw new IOException("Selected file is too large.");out.write(buffer,0,n);}return out.toByteArray();
        }
    }
    private void notificationSettings(){ReminderReceiver.ensureChannel(this);if(android.os.Build.VERSION.SDK_INT>=33&&checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED){requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS},20);return;}Intent i=new Intent(android.os.Build.VERSION.SDK_INT>=26?Settings.ACTION_APP_NOTIFICATION_SETTINGS:Settings.ACTION_APPLICATION_DETAILS_SETTINGS);i.putExtra(Settings.EXTRA_APP_PACKAGE,getPackageName());if(android.os.Build.VERSION.SDK_INT<26)i.setData(android.net.Uri.parse("package:"+getPackageName()));startActivity(i);}
    private void scheduleAll(){JSONArray a=rows(3);for(int i=0;i<a.length();i++)schedule(a.optJSONObject(i));}
    private void schedule(JSONObject record){ReminderReceiver.schedule(this,record);}
    private void cancelReminder(JSONObject record){ReminderReceiver.cancel(this,record.optString("id"));}
}
