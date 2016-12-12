%% VAMO A COMPARARNO
clear all; clc;

a=6378.01e3;
u=3.986012e14;
h=(a+542e3)/a;

ws=sqrt(u/a^3); % Satellite mean motion
we=2*pi/(24*3600); % Earth mean motion

At=1/6; % [min]       % Every 10 seconds
t=0:At:60*30; t=t*60; % Time array in seconds

i=72*pi/180;

p=8;
spp=21;
N=p*spp;
f=0;

latGS=60*pi/180;
longGS=0*pi/180;

f1=pi/2-latGS; f2=longGS;
R1=[cos(f1) 0 -sin(f1);0 1 0;sin(f1) 0 cos(f1)];
R2=[cos(f2) sin(f2) 0; -sin(f2) cos(f2) 0; 0 0 1];
RotGS=R1*R2;

% Rotation Matrix:
% From ECEF - To SEZ
% Where:
% ECEF = Earth Centered Earth Fix - Coordinate System
% SEZ = Topocentric Horizon - Coordinate System

emin=20*pi/180;

%% Le simulasion
Omega = 0:210/(p-1):210; Omega=Omega*pi/180;
nu = zeros(spp,p);
angle = zeros(1,p);
X = zeros(3,spp*p);

flight_time=zeros(1,1000);    % Length of the flyby of a satellite
links_at_time=zeros(1,1000);  % Number of links when one sat has finished
time_end_flyby=zeros(1,1000); % When did this flyby end?

contact=zeros(1,length(t)); % Number of links

quality_time=zeros(1,length(t)); % If a flyby lasts longer than 3 minutes, 
                                 % then the previous 3 minutes were successfuly covered.

time_record=zeros(1,N);     % Accumulates Timesteps being on the GS
before_tracking=zeros(1,N); % Boolean to know which ones are already passing by
now_tracking=zeros(1,N);    % Boolean to know which ones are now passing by
Nflyby=0;                   % Number of flight paths computed

for n=1:length(t)
    
    % Ground Station Coordinates
    f1=we*t(n)+longGS;
    f2=latGS;
    RGS=cos(f2);
    XGS=[RGS*cos(f1);RGS*sin(f1);sin(f2)];

    R2=[cos(f1) sin(f1) 0; -sin(f1) cos(f1) 0; 0 0 1];
    RotGS=R1*R2;
    
    % Constellation Coordinates
    nu_t=ws*t(n);   % True anomaly due to time passing by
    for j = 1:p
        angle(j) = f*2*pi*(j-1)/(spp*p); %Phasing due to f between planes
        for k = 1:spp
            % True anomalies of the s satellites
            A = spp*(j-1)+k; % Number of the satellite
            nu(k,j) = 2*pi*(k-1)/spp+angle(j);
            X(:,A) = cartesian(h,0,i,Omega(j),0,nu(k,j)+nu_t);
        end
    end
    
    % Contact Evaluation
    win=0;
    now_tracking=zeros(1,N);
    for sat=1:N
        X_hor=RotGS*(X(:,sat)-XGS);
%       fprintf('%g,%g,%g --> |r|=%g\n',X_hor(1),X_hor(2),X_hor(3),norm(X_hor))
        ang=asin(X_hor(3)/norm(X_hor));
        if ang >= emin
            win=win+1;
            time_record(sat)=time_record(sat)+1;
            now_tracking(sat)=1;
        end
        
        % Flight time computation and reset of this satellite flyby
        if before_tracking(sat)==1 && now_tracking(sat)==0
            Nflyby=Nflyby+1;
            flight_time(Nflyby)=At*time_record(sat);
            
            links_at_time(Nflyby)=contact(n-1);
            time_end_flyby(Nflyby)=t(n);
            
            % THE KEY QUESTION
            % Was this flyby useful?
            if flight_time(Nflyby)>3
                start=n-time_record(sat);
                finish=n;
                quality_time(start:finish)=quality_time(start:finish)+1;
            end
            time_record(sat)=0; 
        end
    end
    before_tracking=now_tracking;
    contact(n)=win;
end

%% Post-Processing
% PLOT 1: NUMER OF LINKS
figure(1)
title('Links vs Time')
plot(t/(3600),contact)
axis([min(t)/(3600) max(t)/(3600) 0 max(contact)+1]);
fails=length(find(contact==0));
ratio=fails/length(contact);
fprintf('Links on GS         : %g percent of the time\n',(1-ratio)*100)

% PLOT 2: LENGTH OF THE LINKS
figure(2)
plot(flight_time(1:Nflyby));
titola=['Length of the ' num2str(Nflyby) ' flyby s. Mean time = '...
    num2str(mean(flight_time(1:Nflyby))) 'min'];
title(titola)
ylabel('Length (minutes)')
xlabel('Contact')
%xlim([1 Nflyby])

% PLOT 3: ANALYSIS OF THE FLYBYS
figure(3)
index=1:Nflyby; % X variable to the following plots
plot(time_end_flyby(index)/3600,flight_time(index),...
     time_end_flyby(index)/3600,links_at_time(index),...
     t/3600,quality_time);

titola='Flybys Analysis';
title(titola)

legend('Length of flybys','Links by end of flyby','Num of sats @flybys longer than 3 min')

% ylabel(hAx(1),'Length of the Flyby (minutes)')
% ylabel(hAx(2),'Number of simultaneous Flybies')
xlabel('Time (h)')
%xlim([1 Nflyby])

epic_wins=length(find(quality_time>=1));
ratio_covered=epic_wins/length(t);
fprintf('Quality flybys on GS: %g percent of the time\n',ratio_covered*100)
