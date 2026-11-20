package tz.altra.pharmacy;

import java.util.*;

final class Csv {
    private Csv() {}
    static List<String[]> parse(String csv){
        if(csv.startsWith("\ufeff"))csv=csv.substring(1);
        List<List<String>> rows=new ArrayList<>();List<String> row=new ArrayList<>();StringBuilder field=new StringBuilder();
        boolean quoted=false, closed=false;
        for(int i=0;i<csv.length();i++){
            char c=csv.charAt(i);
            if(quoted){if(c=='"'){if(i+1<csv.length()&&csv.charAt(i+1)=='"'){field.append('"');i++;}else{quoted=false;closed=true;}}else field.append(c);continue;}
            if(c==','||c=='\n'||c=='\r'){
                row.add(field.toString().trim());field.setLength(0);closed=false;
                if(c!=','){if(c=='\r'&&i+1<csv.length()&&csv.charAt(i+1)=='\n')i++;if(row.size()>1||!row.get(0).isEmpty())rows.add(row);row=new ArrayList<>();if(rows.size()>501)throw new IllegalArgumentException("Import up to 500 medicines at a time.");}
            }else if(c=='"'&&!closed&&field.length()==0){quoted=true;}
            else if(closed||c=='"'){throw new IllegalArgumentException("Invalid CSV quoting.");}
            else field.append(c);
        }
        if(quoted)throw new IllegalArgumentException("CSV has an unclosed quote.");
        if(!row.isEmpty()||field.length()>0||closed){row.add(field.toString().trim());rows.add(row);}
        if(rows.size()<2||!rows.get(0).equals(Arrays.asList("name","form","supplier","stock","expiry")))throw new IllegalArgumentException("CSV needs at least one record and these headers: name,form,supplier,stock,expiry.");
        if(rows.size()>501)throw new IllegalArgumentException("Import up to 500 medicines at a time.");
        List<String[]> out=new ArrayList<>();for(int i=1;i<rows.size();i++){if(rows.get(i).size()!=5)throw new IllegalArgumentException("CSV record "+i+" must have five columns.");out.add(rows.get(i).toArray(new String[0]));}return out;
    }
}
