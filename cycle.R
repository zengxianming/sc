#���������ڵķ�����������������Ҫ�����
#1.���������ɢ��պö���x=0ǰ���������鷳��
#2.�Ŷӹ�����ʱ���Ŷӵĺ�˻ᱻ��Ϊ�����֡����������ֻ��6m/s*һ�����ʱ���ڵ��Ŷ�������

library(sqldf)
ti<-c()#����һ���������洢��ͣ����ʱ��
cycle<-90#��һ������ڵ�����
pasttime_code<-"C:/Users/10993/Desktop/�ϴ�/ForR/pasttime.R"
direction<-1#�������ݷ���Ĳ����������켣���ݴ�С����Ϊ1

#ѡȡͣ�����ݻ�ȡͨ��ͣ����ʱ�䣬������һ�ݲ��ᱻ�޸ĵ�rawstoppass����
#stoppassͣ��ͨ��������
#redtime�Ǻ��ʱ�䣬ȡ98%��λ��stoppass��ͣ��ʱ��
rawstoppass<-read.table("C:/Users/10993/Desktop/�ϴ�/ForR/stoppass.csv",header=T,sep=",")
stoppass<-rawstoppass
stoppass$stoptime<-stoppass$l_t-stoppass$f_t#����ͣ��ʱ��
redtime<-quantile(stoppass$stoptime,0.98)/0.98#����Ϊ���ȵ����ôȡ0.98��λ���ͻ�Ӧ�÷���1/0.98����
stopline<-max(stoppass$y)#ͣ����λ��

stoppass<-stoppass[which(stoppass$y<6*redtime),]#��һ��ע��ĸ�

accum<-function(array,x){
  return(length(array[array<x])/length(array))
}

#ѡȡ����ͨ�����ݻ�ȡͨ��ͣ����ʱ��
#freepass����ͨ������������
freepass<-read.table("C:/Users/10993/Desktop/�ϴ�/ForR/freepass.csv",header=T,sep=",")
distinct_vec_no<-sqldf("select distinct vec_no from freepass")#ѡȡͨ��ͣ���ߵ����г������
for (x in distinct_vec_no[,1]){
  tra<-freepass[which(freepass$vec_no==x),]#ѡȡÿһ�����Ĺ켣
  n<-nrow(tra)
  tra<-sqldf("select t as time,len from tra order by len desc")#����ʻ���뽵������
  for(j in 1:(n-1)){
    if (tra[j,2]>=stopline && tra[j+1,2]<stopline){
      ti[length(ti)+1]<-(tra[j+1,1]-tra[j,1])/(tra[j+1,2]-tra[j,2])*(stopline-tra[j,2])+tra[j,1]
    }
  }
}

#rsqΪ��ɢ���������R��
#greenshotΪ�л��̵�ʱ��
#depΪ�Ŷ���ɢ�ٶ�(depart)
#cycleΪ���ڳ���
rsq<-0
for(x in ceiling(redtime):600){
  lim<-summary(lm(stoppass$y~(stoppass$l_t%%x)))
  rsqua<-lim$adj.r.squared
  GreenShot<--(lim$coefficients[1,1]-stopline)/lim$coefficients[2,1]
  ticyc<-ti%%x
  green<-GreenShot-0.1*redtime
  red<-0.8*redtime
  if (green>red) y<-length(ticyc[ticyc>green|ticyc<(green-red)])
  if (green<red) y<-length(ticyc[ticyc>green&ticyc<(green-red+x)])
  y<-rsqua/(1+max(0.95*length(ticyc)-y,0))
  if (rsq<y) {rsq<-y;dep<-lim$coefficients[2,1];cycle<-x;greenshot<-GreenShot}
}

#���������ڷ���
stoppass$lt<-stoppass$l_t-greenshot+0.5*cycle
stoppass$cycleno<-stoppass$lt%/%cycle+1

#�����ȡ��������
pr=0.05
fcd<-stoppass[sample(nrow(stoppass),ceiling(nrow(stoppass)*pr)),]

#cycΪ��ͬ���ڣ�������ݿ���cycno��Ψһ����
cyc<-data.frame(no=1:max(fcd$cycleno))
#�����ȷ��ÿ�����ڵĺ�ƿ�ʼʱ��
cyc$red<-round((cyc$no-1)*cycle+greenshot-redtime,0)
#�����ȷ��ÿ�����ڵ��̵ƿ�ʼʱ��
cyc$gre<-round((cyc$no-1)*cycle+greenshot,0)
#����������������
cyc$y<-stopline

#special_pointΪ���������㣬f_tΪ�����꣬yΪ�����꣬cyclenoΪ���ڱ��
special_point<-subset(fcd,select=c(f_t,y,cycleno))
special_point<-rbind(special_point,data.frame(f_t=cyc$red,y=cyc$y,cycleno=cyc$no))
special_point<-special_point[order(special_point$f_t),]

source(pasttime_code)

#�������ⲿ��Ҫ�������뵥λ����ͣ�����ȵĳ˻�len_vol
cyc$len_vol<-NA
for(x in 1:max(fcd$cycleno)){
  if(nrow(special_point[which(special_point$cycleno==x),])>1){
    maxx<-sqldf(paste("select max(f_t) from special_point where cycleno=",x))
    maxy<-sqldf(paste("select max(y) from special_point where cycleno=",x))
    minx<-sqldf(paste("select min(f_t) from special_point where cycleno=",x))
    miny<-sqldf(paste("select min(y) from special_point where cycleno=",x))
    cyc[x,5]<-(maxy-miny)/(accum(ti,as.numeric(maxx%%cycle))-accum(ti,as.numeric(minx%%cycle)))
  }
}

#�޳��쳣len_vol���ֱܴ��Ĵ�����������δ������ģ�
normal<-quantile(cyc$len_vol,.75,na.rm=T)
for(x in 1:max(fcd$cycleno)){
  if(!is.na(cyc[x,5])){
    if(cyc[x,5]>normal) cyc[x,5]<-normal    
  }
}

#�����������ȥ�滻ȷʵ��len_vol����
for(x in 1:max(fcd$cycleno)){
  if(is.na(cyc[x,5])){
    min<-max(fcd$cycleno)
    minmark<-1
    for(y in 1:max(fcd$cycleno)){
      if(!is.na(cyc[y,5])){if(abs(y-x)<min) {minmark<-y;min<-abs(y-x)}}
    }
    cyc[x,5]<-cyc[minmark,5]
  }
}

#�Ŷ�һ�������ڵ��Ŷ�����
#ti���ڼ����ۼ�Ƶ����������
spe<-mean(stoppass$f_k)
len<-c()
len[1]<-0
for(x in 1:cycle){
  per[x+1]<-queue(0,x,cyc[1,5],spe,accum,ti)$root
}
plot(0:cycle,per,type="l")

#�����յ�����ϵ
plot(0,0,xlim=c(0,500),ylim=c(min(stoppass$y)-100,max(stoppass$y)+100))
#��ÿ���������Ŷ�����
for(x in 1:max(fcd$cycleno)){
  former_x<-cyc[x,2];former_y<-stopline;
  latter_x<-cyc[x,2]+1;latter_y<-0;
  #��������Ƶĵ����̵��л��������б��С����ɢ��б�ʣ��������ɢ�����߲���ֹѭ��
  while(!(latter_x>cyc[x,3]&abs(latter_y-stopline)/(latter_x-cyc[x,3])<abs(dep))){
    latter_y<-queue((cyc[x,2]+0.5)%%cycle,latter_x%%cycle,cyc[x,5],spe,accum,ti)$root
    latter_y<-stopline-direction*latter_y
    lines(c(former_x,latter_x),c(former_y,latter_y),type="l")
    #���ݵ���
    former_x<-latter_x;former_y<-latter_y;latter_x<-latter_x+1;
  }
  lines(c(cyc[x,3],latter_x),c(stopline,latter_y),type="l")
}