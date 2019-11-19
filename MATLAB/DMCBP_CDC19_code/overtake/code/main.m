function main

%% state include dx, y, vx, vy, vx_opp, level
clear global;
global Goal nx dx_set_ego y_set_ego vx_set_ego vy_set_ego vx_set_opp...
       opp_level delta_t u w nu nw w_car l_car w_lane...
       decay

w_car = 2;
l_car = 5;
w_lane = 4;
delta_t = 1;
Goal = [8,0];
dx_set_ego = [-8:1:8];
y_set_ego = [0, 2.5];
decay = 0.8;
vx_set_ego = [0:2:6];
vy_set_ego = [-2.5,0,2.5];
vx_set_opp = [0:2:4];
opp_level = [1,2];
u = [[-2,-2.5];  [0,-2.5];  [2,-2.5];...
       [-2,0]; [0,0]; [2,0];...
        [-2,2.5]; [0, 2.5]; [2,2.5]];

w = [-2; 0; 2];

nu = size(u,1);
nw = size(w,1);

n_dx_set_ego = size(dx_set_ego,2);
n_y_set_ego = size(y_set_ego,2);

n_vx_ego = size(vx_set_ego,2);
n_vy_ego = size(vy_set_ego,2);

n_vx_opp = size(vx_set_opp,2);

n_opp_level = 2;
%% state include dx, y, vx, vy, vx_opp, level 8*2*4*2*3*2
nx = n_dx_set_ego * n_y_set_ego * n_vx_ego * n_vy_ego * n_vx_opp * n_opp_level ;

global Cost_vec  Violation_indices  confidence_level

X = index_to_state([1:1:nx],dx_set_ego,y_set_ego,  vx_set_ego,...
     vy_set_ego, vx_set_opp,opp_level);
Cost_vec = cost(X)';
Violation_indices = const(X)';
confidence_level = 0.99;
run = 0;

if run == 1
    Px = zeros(nx,nx,nu);
    step = 1;
    for j = 1 : nx
        for k = 1 : nu
            for l = 1 : nw
               % calculate the new state index, j is the current state index, k
               % is the ego vehicle action index, w is the opponent vehicle
               % action index
               pw = get_pw(j,l);
               i=ffunc(j,k,l);
               Px(i,j,k) = Px(i,j,k) + pw;
               step = step + 1;
               step
            end
        end
    end


    ny = nx/2;
    Dy = y_index_to_state([1:1:nx/2],dx_set_ego,y_set_ego,  vx_set_ego,...
         vy_set_ego, vx_set_opp);

    Py = zeros(ny, nx);
    step = 1;
    for j = 1 : nx
        step
        m = gfunc(j);
        Py(m,j) = 1;
        step = step + 1
    end
    
 Px_full = Px;
 Px = cell(nu,1);
 for(k=1:1:nu)
     Px{k} = sparse(Px_full(:,:,k));
 end
 Py = sparse(Py);

save workspace
else 
  load('workspace.mat');  
end 
%% test Py Px
% for(k=1:nu)
%     Px_k = Px(:,:,k);
%     for(j=1:nx)
%         sum(Px_k(:,j))
%     end
% end
%
% for(j=1:ny)
%     sum(Py(:,j))
% end
%%%%%


global Px Py pi_t0 N

Violation_count = 0;
N = 3;
Gamma = zeros(nu*N,1);
A = [eye(length(Gamma));
    -eye(length(Gamma))];
b = [ones(length(Gamma),1);
    zeros(length(Gamma),1)];
Aeq = [ones(1,nu) zeros(1,length(Gamma)-nu);
    zeros(1,nu) ones(1,nu) zeros(1,length(Gamma)-2*nu);
    zeros(1,2*nu) ones(1,nu) ];
beq = ones(N,1);

x_0 = [-8; 0; 0; 0; 0; 2];
x_0_0 = [-8; 0; 0; 0; 0; 1];
x_t1 = x_0;
x_index_0 = state_to_index(x_0,dx_set_ego,y_set_ego,  vx_set_ego,...
     vy_set_ego, vx_set_opp,opp_level);
x_index_0_0 = state_to_index(x_0_0,dx_set_ego,y_set_ego,  vx_set_ego,...
     vy_set_ego, vx_set_opp,opp_level);
x_index_t1 = x_index_0;

pi_t0 = zeros(nx,1);
pi_t0(x_index_0,1) = 0.5;
pi_t0(x_index_0_0,1) = 0.5;
pi_t1 = pi_t0;

step = 1;
if_goal = 0;

states_history = [x_t1];
while(~if_goal)
    step
    x_index_t0 = x_index_t1;
    x_states_t0 = index_to_state(x_index_t0,dx_set_ego,y_set_ego,  vx_set_ego,...
     vy_set_ego, vx_set_opp,opp_level);

    pi_t0 = pi_t1;
    Gamma0 = ones(nu*N,1)/nu;
    tic
    [Gamma, fval] = fmincon(@Cost,Gamma0,A,b,Aeq,beq,[],[],@Const,[]);
    toc
    gamma = Gamma(1:nu);
    random = rand();
    sum_rand = 0;


   for(k=1:1:nu)
       sum_rand = sum_rand+gamma(k);
       if(sum_rand>random)
         u_index_t0 = k;
       break
       end
   end


   w_index_t0 = get_opp_action(x_states_t0, 1);


   x_index_t1 = ffunc(x_index_t0,u_index_t0,w_index_t0);
   y_index_t1 = gfunc(x_index_t1);
   pi_t1 = Bayesian(pi_t0,y_index_t1,u_index_t0);


   if(ismember(x_index_t1,Violation_indices))
        Violation_count = Violation_count+1;
   end

   x_t1 = index_to_state(x_index_t1,dx_set_ego,y_set_ego,  vx_set_ego,...
     vy_set_ego, vx_set_opp,opp_level);
   if_goal = reach_goal(x_t1);
   states_history = [states_history, x_t1];
   x_t1
   step = step + 1;



end

save states_history_opp1;

plot_history = get_picture(1);



Violation_count = 0;
N = 3;
Gamma = zeros(nu*N,1);
A = [eye(length(Gamma));
    -eye(length(Gamma))];
b = [ones(length(Gamma),1);
    zeros(length(Gamma),1)];
Aeq = [ones(1,nu) zeros(1,length(Gamma)-nu);
    zeros(1,nu) ones(1,nu) zeros(1,length(Gamma)-2*nu);
    zeros(1,2*nu) ones(1,nu) ];
beq = ones(N,1);

x_0 = [-8; 0; 0; 0; 0; 2];
x_0_0 = [-8; 0; 0; 0; 0; 1];
x_t1 = x_0;
x_index_0 = state_to_index(x_0,dx_set_ego,y_set_ego,  vx_set_ego,...
     vy_set_ego, vx_set_opp,opp_level);
x_index_0_0 = state_to_index(x_0_0,dx_set_ego,y_set_ego,  vx_set_ego,...
     vy_set_ego, vx_set_opp,opp_level);
x_index_t1 = x_index_0;

pi_t0 = zeros(nx,1);
pi_t0(x_index_0,1) = 0.5;
pi_t0(x_index_0_0,1) = 0.5;
pi_t1 = pi_t0;

step = 1;
if_goal = 0;

states_history = [x_t1];
while(~if_goal)
    step
    x_index_t0 = x_index_t1;
    x_states_t0 = index_to_state(x_index_t0,dx_set_ego,y_set_ego,  vx_set_ego,...
     vy_set_ego, vx_set_opp,opp_level);

    pi_t0 = pi_t1;
    Gamma0 = ones(nu*N,1)/nu;
    Gamma = fmincon(@Cost,Gamma0,A,b,Aeq,beq,[],[],@Const,[]);
    gamma = Gamma(1:nu);
    random = rand();
    sum_rand = 0;


   for(k=1:1:nu)
       sum_rand = sum_rand+gamma(k);
       if(sum_rand>random)
         u_index_t0 = k;
       break
       end
   end


   w_index_t0 = get_opp_action(x_states_t0, 2);


   x_index_t1 = ffunc(x_index_t0,u_index_t0,w_index_t0);
   y_index_t1 = gfunc(x_index_t1);
   pi_t1 = Bayesian(pi_t0,y_index_t1,u_index_t0);


   if(ismember(x_index_t1,Violation_indices))
        Violation_count = Violation_count+1;
   end

   x_t1 = index_to_state(x_index_t1,dx_set_ego,y_set_ego,  vx_set_ego,...
     vy_set_ego, vx_set_opp,opp_level);
   if_goal = reach_goal(x_t1);
   states_history = [states_history, x_t1];
   x_t1
   step = step + 1;



end

save states_history_opp2;
plot_history = get_picture(2);


end

function get_picture = get_picture(level)
  global w_lane  w_car l_car
  get_picture = 0;
  w_lane = 4;
  w_car = 2;
   l_car = 5;

if level == 1
load 'states_history_opp1.mat'
X_all = states_history;

dt = 1;

X_new = [X_all(1,1),X_all(2,1)-2,0,0,-2,0];
for i = 2:1:size(X_all,2)
    x_opp_temp = X_new(i-1,4) + X_all(5,i)*dt;
    y_opp_temp = -2;
    theta_opp_temp = 0;
    x_ego_temp = x_opp_temp + X_all(1,i);
    y_ego_temp = X_all(2,i)-2;
    if y_ego_temp > 0
        y_ego_temp = 2;
    end
    theta_ego_temp = 0;
    X_new = [X_new; x_ego_temp, y_ego_temp, theta_ego_temp, x_opp_temp, y_opp_temp, theta_opp_temp];
    
    
end

 RoadBound = [-40,4;
                40,4;              
                40,80;               
                -40,80;
                -40,-4;
                40,-4;              
                40,-80;               
                -40,-80;                      
                ];
                       
color = ['b' 'r' 'm' 'g'];
car_id = 1;        
car_opp = 2;

for i = 1: 1: size(X_new, 1)
    
    fig = figure('visible','on');
    set(gcf,'units','centimeters','position',[0,0,20,12])
    set(gca,'fontsize',20)
    
    step = i;
    pause(0.001);
    X = X_all(:, i);
    plot(RoadBound(1:4,1),RoadBound(1:4,2),'k-','LineWidth',4)
    hold on
    plot(RoadBound(5:8,1),RoadBound(5:8,2),'k-','LineWidth',4)
    
    
    plot([-40, 29],[0,0],'--','color',[0.75 0.75 0.75],'LineWidth',3)
    
    
    X_old = X_new(i,:);
    Ego_rectangle = [X_old(1)-l_car/2*cos(X_old(3))-w_car/2*sin(X_old(3)), X_old(2)-l_car/2*sin(X_old(3))+w_car/2*cos(X_old(3));
                X_old(1)-l_car/2*cos(X_old(3))+w_car/2*sin(X_old(3)), X_old(2)-l_car/2*sin(X_old(3))-w_car/2*cos(X_old(3));
                X_old(1)+l_car/2*cos(X_old(3))-w_car/2*sin(X_old(3)), X_old(2)+l_car/2*sin(X_old(3))+w_car/2*cos(X_old(3));
                X_old(1)+l_car/2*cos(X_old(3))+w_car/2*sin(X_old(3)), X_old(2)+l_car/2*sin(X_old(3))-w_car/2*cos(X_old(3));
                X_old(1)+(l_car/2-1)*cos(X_old(3))-w_car/2*sin(X_old(3)), X_old(2)+(l_car/2-1)*sin(X_old(3))+w_car/2*cos(X_old(3));
                X_old(1)+(l_car/2-1)*cos(X_old(3))+w_car/2*sin(X_old(3)), X_old(2)+(l_car/2-1)*sin(X_old(3))-w_car/2*cos(X_old(3))];
    
   plot([Ego_rectangle(1,1) Ego_rectangle(2,1)],[Ego_rectangle(1,2) Ego_rectangle(2,2)],'-','LineWidth',2,'Color',color(car_id));
   plot([Ego_rectangle(1,1) Ego_rectangle(3,1)],[Ego_rectangle(1,2) Ego_rectangle(3,2)],'-','LineWidth',2,'Color',color(car_id));
   plot([Ego_rectangle(3,1) Ego_rectangle(4,1)],[Ego_rectangle(3,2) Ego_rectangle(4,2)],'-','LineWidth',2,'Color',color(car_id));
   plot([Ego_rectangle(2,1) Ego_rectangle(4,1)],[Ego_rectangle(2,2) Ego_rectangle(4,2)],'-','LineWidth',2,'Color',color(car_id));
   plot([Ego_rectangle(5,1) Ego_rectangle(6,1)],[Ego_rectangle(5,2) Ego_rectangle(6,2)],'-','LineWidth',2,'Color',color(car_id));         
   
   Opp_rectangle = [X_old(4)-l_car/2*cos(X_old(6))-w_car/2*sin(X_old(6)), X_old(5)-l_car/2*sin(X_old(6))+w_car/2*cos(X_old(6));
                X_old(4)-l_car/2*cos(X_old(6))+w_car/2*sin(X_old(6)), X_old(5)-l_car/2*sin(X_old(6))-w_car/2*cos(X_old(6));
                X_old(4)+l_car/2*cos(X_old(6))-w_car/2*sin(X_old(6)), X_old(5)+l_car/2*sin(X_old(6))+w_car/2*cos(X_old(6));
                X_old(4)+l_car/2*cos(X_old(6))+w_car/2*sin(X_old(6)), X_old(5)+l_car/2*sin(X_old(6))-w_car/2*cos(X_old(6));
                X_old(4)+(l_car/2-1)*cos(X_old(6))-w_car/2*sin(X_old(6)), X_old(5)+(l_car/2-1)*sin(X_old(6))+w_car/2*cos(X_old(6));
                X_old(4)+(l_car/2-1)*cos(X_old(6))+w_car/2*sin(X_old(6)), X_old(5)+(l_car/2-1)*sin(X_old(6))-w_car/2*cos(X_old(6))];
            
   plot([Opp_rectangle(1,1) Opp_rectangle(2,1)],[Opp_rectangle(1,2) Opp_rectangle(2,2)],'-','LineWidth',2,'Color',color(car_opp));
   plot([Opp_rectangle(1,1) Opp_rectangle(3,1)],[Opp_rectangle(1,2) Opp_rectangle(3,2)],'-','LineWidth',2,'Color',color(car_opp));
   plot([Opp_rectangle(3,1) Opp_rectangle(4,1)],[Opp_rectangle(3,2) Opp_rectangle(4,2)],'-','LineWidth',2,'Color',color(car_opp));
   plot([Opp_rectangle(2,1) Opp_rectangle(4,1)],[Opp_rectangle(2,2) Opp_rectangle(4,2)],'-','LineWidth',2,'Color',color(car_opp));
   plot([Opp_rectangle(5,1) Opp_rectangle(6,1)],[Opp_rectangle(5,2) Opp_rectangle(6,2)],'-','LineWidth',2,'Color',color(car_opp));         
   axis([-15 25 -12 12])
   set(gca,'xtick',[])
   set(gca,'ytick',[])
   set( gca, 'XTick', -15 : 5 : 25 )
   set( gca, 'YTick', -15 : 5 : 15 )
    xlabel('[m]')
    ylabel('[m]')
    annotation('textbox',...
    [0.65 0.16 0.24 0.2],...
    'String',{['v_{1} = ' num2str(X_all(3,i)+24) ' m/s '],...
               ['v_{2} = ' num2str(X_all(5,i)+24) ' m/s ']},...
    'FontSize',20,...
    'FontName','Arial',...
    'LineStyle','-',...
    'EdgeColor',[0.85 0.85 0.85],...
    'LineWidth',2,...
    'BackgroundColor',[0.95  0.95 0.95],...
    'Color','k');
   
  % axis equal
   print( '-depsc', [ '-r', int2str( 1000 ) ], [ sprintf('overtake_opp_1_step_%d', i), '.eps' ]) 
    
end
close all;
get_picture = 1;
end


if level == 2

load 'states_history_opp2.mat'
X_all = states_history;

dt = 1;

X_new = [X_all(1,1),X_all(2,1)-2,0,0,-2,0];
for i = 2:1:size(X_all,2)
    x_opp_temp = X_new(i-1,4) + X_all(5,i)*dt;
    y_opp_temp = -2;
    theta_opp_temp = 0;
    x_ego_temp = x_opp_temp + X_all(1,i);
    y_ego_temp = X_all(2,i)-2;
    if y_ego_temp > 0
        y_ego_temp = 2;
    end
    theta_ego_temp = 0;
    X_new = [X_new; x_ego_temp, y_ego_temp, theta_ego_temp, x_opp_temp, y_opp_temp, theta_opp_temp];
    
    
end

 RoadBound = [-40,4;
                40,4;              
                40,80;               
                -40,80;
                -40,-4;
                40,-4;              
                40,-80;               
                -40,-80;                      
                ];
                       
color = ['b' 'r' 'm' 'g'];
car_id = 1;        
car_opp = 2;

for i = 1: 1: size(X_new, 1)
    
    fig = figure('visible','on');
    set(gcf,'units','centimeters','position',[0,0,20,12])
    set(gca,'fontsize',20)
    
    step = i;
    pause(0.001);
    X = X_all(:, i);
    plot(RoadBound(1:4,1),RoadBound(1:4,2),'k-','LineWidth',4)
    hold on
    plot(RoadBound(5:8,1),RoadBound(5:8,2),'k-','LineWidth',4)
    
    
    plot([-40, 29],[0,0],'--','color',[0.75 0.75 0.75],'LineWidth',3)
    
    
    X_old = X_new(i,:);
    Ego_rectangle = [X_old(1)-l_car/2*cos(X_old(3))-w_car/2*sin(X_old(3)), X_old(2)-l_car/2*sin(X_old(3))+w_car/2*cos(X_old(3));
                X_old(1)-l_car/2*cos(X_old(3))+w_car/2*sin(X_old(3)), X_old(2)-l_car/2*sin(X_old(3))-w_car/2*cos(X_old(3));
                X_old(1)+l_car/2*cos(X_old(3))-w_car/2*sin(X_old(3)), X_old(2)+l_car/2*sin(X_old(3))+w_car/2*cos(X_old(3));
                X_old(1)+l_car/2*cos(X_old(3))+w_car/2*sin(X_old(3)), X_old(2)+l_car/2*sin(X_old(3))-w_car/2*cos(X_old(3));
                X_old(1)+(l_car/2-1)*cos(X_old(3))-w_car/2*sin(X_old(3)), X_old(2)+(l_car/2-1)*sin(X_old(3))+w_car/2*cos(X_old(3));
                X_old(1)+(l_car/2-1)*cos(X_old(3))+w_car/2*sin(X_old(3)), X_old(2)+(l_car/2-1)*sin(X_old(3))-w_car/2*cos(X_old(3))];
    
   plot([Ego_rectangle(1,1) Ego_rectangle(2,1)],[Ego_rectangle(1,2) Ego_rectangle(2,2)],'-','LineWidth',2,'Color',color(car_id));
   plot([Ego_rectangle(1,1) Ego_rectangle(3,1)],[Ego_rectangle(1,2) Ego_rectangle(3,2)],'-','LineWidth',2,'Color',color(car_id));
   plot([Ego_rectangle(3,1) Ego_rectangle(4,1)],[Ego_rectangle(3,2) Ego_rectangle(4,2)],'-','LineWidth',2,'Color',color(car_id));
   plot([Ego_rectangle(2,1) Ego_rectangle(4,1)],[Ego_rectangle(2,2) Ego_rectangle(4,2)],'-','LineWidth',2,'Color',color(car_id));
   plot([Ego_rectangle(5,1) Ego_rectangle(6,1)],[Ego_rectangle(5,2) Ego_rectangle(6,2)],'-','LineWidth',2,'Color',color(car_id));         
   
   Opp_rectangle = [X_old(4)-l_car/2*cos(X_old(6))-w_car/2*sin(X_old(6)), X_old(5)-l_car/2*sin(X_old(6))+w_car/2*cos(X_old(6));
                X_old(4)-l_car/2*cos(X_old(6))+w_car/2*sin(X_old(6)), X_old(5)-l_car/2*sin(X_old(6))-w_car/2*cos(X_old(6));
                X_old(4)+l_car/2*cos(X_old(6))-w_car/2*sin(X_old(6)), X_old(5)+l_car/2*sin(X_old(6))+w_car/2*cos(X_old(6));
                X_old(4)+l_car/2*cos(X_old(6))+w_car/2*sin(X_old(6)), X_old(5)+l_car/2*sin(X_old(6))-w_car/2*cos(X_old(6));
                X_old(4)+(l_car/2-1)*cos(X_old(6))-w_car/2*sin(X_old(6)), X_old(5)+(l_car/2-1)*sin(X_old(6))+w_car/2*cos(X_old(6));
                X_old(4)+(l_car/2-1)*cos(X_old(6))+w_car/2*sin(X_old(6)), X_old(5)+(l_car/2-1)*sin(X_old(6))-w_car/2*cos(X_old(6))];
            
   plot([Opp_rectangle(1,1) Opp_rectangle(2,1)],[Opp_rectangle(1,2) Opp_rectangle(2,2)],'-','LineWidth',2,'Color',color(car_opp));
   plot([Opp_rectangle(1,1) Opp_rectangle(3,1)],[Opp_rectangle(1,2) Opp_rectangle(3,2)],'-','LineWidth',2,'Color',color(car_opp));
   plot([Opp_rectangle(3,1) Opp_rectangle(4,1)],[Opp_rectangle(3,2) Opp_rectangle(4,2)],'-','LineWidth',2,'Color',color(car_opp));
   plot([Opp_rectangle(2,1) Opp_rectangle(4,1)],[Opp_rectangle(2,2) Opp_rectangle(4,2)],'-','LineWidth',2,'Color',color(car_opp));
   plot([Opp_rectangle(5,1) Opp_rectangle(6,1)],[Opp_rectangle(5,2) Opp_rectangle(6,2)],'-','LineWidth',2,'Color',color(car_opp));         
   axis([-15 25 -12 12])
   set(gca,'xtick',[])
   set(gca,'ytick',[])
   set( gca, 'XTick', -15 : 5 : 25 )
   set( gca, 'YTick', -15 : 5 : 15 )
    xlabel('[m]')
    ylabel('[m]')
    annotation('textbox',...
    [0.65 0.16 0.24 0.2],...
    'String',{['v_{1} = ' num2str(X_all(3,i)+24) ' m/s '],...
               ['v_{2} = ' num2str(X_all(5,i)+24) ' m/s ']},...
    'FontSize',20,...
    'FontName','Arial',...
    'LineStyle','-',...
    'EdgeColor',[0.85 0.85 0.85],...
    'LineWidth',2,...
    'BackgroundColor',[0.95  0.95 0.95],...
    'Color','k');
   
  % axis equal
   print( '-depsc', [ '-r', int2str( 1000 ) ], [ sprintf('overtake_opp_2_step_%d', i), '.eps' ]) 
    
end
close all;
get_picture = 2;
end



end



function if_goal = reach_goal(X)
    global Goal
    if_goal = 0;
    if (X(1) == Goal(1) && X(2) == Goal(2))
        if_goal = 1;
    end
end

function action_index = get_opp_action(y, level)
    global nw
    action_probability = [];
    probability_action_one_step = [];
    horizon = 2;
    if level == 1
       random = rand();
       sum_rand = 0;
       action_probability = L_1(y, 2, horizon);
       probability_action_one_step = [sum(action_probability(1:3)),sum(action_probability(4:6)), sum(action_probability(7:9))];
       for l=1:1:nw
           sum_rand = sum_rand + probability_action_one_step(l);
           if(sum_rand>random)
              action_index = l;
           break
           end
       end

    end

    if level == 2
       %random = rand();
       %sum_rand = 0;
       action_probability = L_2(y, 2, horizon);
       probability_action_one_step = [sum(action_probability(1:3)),sum(action_probability(4:6)), sum(action_probability(7:9))];
       %for l=1:1:nw
       %    sum_rand = sum_rand+probability_action_one_step(l);

       %    if(sum_rand>random)
       %       action_index = l;
       %    break
       %    end
       %end

       [~, action_index] = max(probability_action_one_step);

    end



end


function x = index_to_state(x_index,x1,x2,x3,x4,x5,x6)

    x1_length = length(x1);
    x2_length = length(x2);
    x3_length = length(x3);
    x4_length = length(x4);
    x5_length = length(x5);
    x6_length = length(x6);

    size = [x1_length,x2_length,x3_length,x4_length,x5_length,x6_length];
    [x1_index,x2_index,x3_index,x4_index,x5_index,x6_index] = ind2sub(size,x_index);

    x = [x1(x1_index);x2(x2_index);x3(x3_index);x4(x4_index);x5(x5_index);x6(x6_index)];
end


function x_index = state_to_index(x,x1,x2,x3,x4,x5,x6)

    x1_index = dsearchn(x1',x(1,:)');
    x2_index = dsearchn(x2',x(2,:)');
    x3_index = dsearchn(x3',x(3,:)');
    x4_index = dsearchn(x4',x(4,:)');
    x5_index = dsearchn(x5',x(5,:)');
    x6_index = dsearchn(x6',x(6,:)');

    x1_length = length(x1);
    x2_length = length(x2);
    x3_length = length(x3);
    x4_length = length(x4);
    x5_length = length(x5);
    x6_length = length(x6);

    size = [x1_length,x2_length,x3_length,x4_length,x5_length,x6_length];
    x_index = sub2ind(size,x1_index,x2_index,x3_index,x4_index,x5_index,x6_index);
end
% x = [dx_ego, y_ego,vx_ego, vy_ego, vx_opp, opp_level];
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%important function
function x_new = update_state(x_old, car_index, action_index)
    global u w delta_t
    x_new = x_old;

    if car_index == 1
        a = u(action_index,:);
        ax = a(1);
        ay = a(2);
        x_new(3) = x_old(3) + ax * delta_t;
        x_new(4) = x_old(4) + ay * delta_t;
        if x_new(3) > 6
            x_new(3) = 6;
        end
        if x_new(3) < 0
            x_new(3) = 0;
        end

        if x_new(4) > 2.5
           x_new(4) = 2.5;
        end

        if x_new(4) < -2.5
            x_new(4) = -2.5;
        end

        % should limit the velocity
        x_new(1) = x_old(1) + delta_t * (x_new(3) - x_old(5));
        x_new(2) = x_old(2) + delta_t * x_new(4);

        if x_new(2) > 2.5
            x_new(2) = 2.5;
        end

        if x_new(2) < 0
            x_new(2) = 0;
        end

    end

    if car_index == 2
        x_new(5) = x_old(5) + (w(action_index) * delta_t);
        if x_new(5) > 4
            x_new(5) = 4;
        end
        if x_new(5) < 0
            x_new(5) = 0;
        end

        x_new(1) = x_old(1) + delta_t * (x_new(3) -  x_new(5));

    end

end

function x_new_index = ffunc(x_old_index, u_index, w_index)
    global  dx_set_ego y_set_ego vx_set_ego vy_set_ego vx_set_opp opp_level
    % convert the state index to state
    x_old = index_to_state(x_old_index,dx_set_ego,y_set_ego,  vx_set_ego,...
     vy_set_ego, vx_set_opp,opp_level);

    % To do: update the state
    x_new_1 = update_state(x_old, 1, u_index);
    x_new_2 = update_state(x_new_1, 2, w_index);

    % convert the new state back to the index
    x_new_index = state_to_index(x_new_2,dx_set_ego,y_set_ego,  vx_set_ego,...
     vy_set_ego, vx_set_opp,opp_level);

end

function y_index_t0 = gfunc(x_index_t0)
    global dx_set_ego y_set_ego vx_set_ego vy_set_ego vx_set_opp opp_level

    x_t0 = index_to_state(x_index_t0,dx_set_ego,y_set_ego,  vx_set_ego,...
     vy_set_ego, vx_set_opp,opp_level);

    y_t0 = x_t0(1:5);

    y_index_t0 = state_to_index_y(y_t0, dx_set_ego,y_set_ego,  vx_set_ego,...
     vy_set_ego, vx_set_opp);

end

function y =  y_index_to_state(x_index,x1,x2,x3,x4,x5)

    x1_length = length(x1);
    x2_length = length(x2);
    x3_length = length(x3);
    x4_length = length(x4);
    x5_length = length(x5);

    size = [x1_length,x2_length,x3_length,x4_length,x5_length];
    [x1_index,x2_index,x3_index,x4_index,x5_index] = ind2sub(size,x_index);

    y = [x1(x1_index);x2(x2_index);x3(x3_index);x4(x4_index);x5(x5_index)];
end


function y_index = state_to_index_y(x,x1,x2,x3,x4,x5)

    x1_index = dsearchn(x1',x(1,:)');
    x2_index = dsearchn(x2',x(2,:)');
    x3_index = dsearchn(x3',x(3,:)');
    x4_index = dsearchn(x4',x(4,:)');
    x5_index = dsearchn(x5',x(5,:)');

    x1_length = length(x1);
    x2_length = length(x2);
    x3_length = length(x3);
    x4_length = length(x4);
    x5_length = length(x5);

    size = [x1_length,x2_length,x3_length,x4_length,x5_length];
    y_index = sub2ind(size,x1_index,x2_index,x3_index,x4_index,x5_index);
end

function Actions_set_index= get_action_sequence(horizon, car_id)
    global nu nw
    if car_id == 1
        Actions_set_index = permn([1:1:nu],horizon);
    end

    if car_id == 2
       Actions_set_index = permn([1:1:nw],horizon);
    end


end

function action_index = L_0(x, car_id, horizon)
    global decay
    Actions_index = get_action_sequence(horizon, car_id);
    R_max = -10000;
    result = [];
    for i = 1:1:size(Actions_index, 1)
            r = 0;
            x_temp = x;
         for j = 1:1:horizon
                x_temp = update_state(x_temp,car_id, Actions_index(i,j));
                r = r + decay^(j - 1) * reward(x_temp,car_id);
         end

         if r > R_max
                R_max = r;
                result = Actions_index(i,:);
         end
    end

    action_index = result;

end

function action_p_1 = L_1(x, car_index, horizon)
    global decay
    Actions_index = get_action_sequence(horizon, car_index);
    action_p_1 = [];
    if car_index == 1
        opp_index = 2;
    else
        opp_index = 1;
    end

    rewards = [];

    opp_action_sequence = L_0(x, opp_index, horizon);

    for i = 1:1:size(Actions_index, 1)
        r = 0;
        x_temp = x;
        for j = 1:1:horizon
            % one time step
            % opp car process
            x_temp = update_state(x_temp, opp_index, opp_action_sequence(j));
            % ego car process
            x_temp = update_state(x_temp,car_index, Actions_index(i,j));
            r = r + decay^(j - 1)*reward(x_temp,car_index);
        end
        rewards = [rewards, r];
    end

    sum_p = 0;

    for i = 1:1:size(rewards,2)
        sum_p = sum_p + exp((rewards(i)));
    end

    for i = 1:1:size(rewards,2)
        action_p_1 = [action_p_1, exp((rewards(i)))/sum_p];
    end

end

function action_p_2 = L_2(x, car_index, horizon)
   global decay
   Actions_index = get_action_sequence(horizon, car_index);
   action_p_2 = [];
   if car_index == 1
       opp_index = 2;
   else
       opp_index = 1;
   end

   opp_action_probability = L_1(x, opp_index, horizon);

   rewards = [];
   for i = 1:1:size(Actions_index, 1)
       reward_curr = 0;
       for j = 1:1:size(Actions_index, 1)
             x_temp = x;
             r = 0;
          for step = 1:1:horizon
               % one time step
               % opp car process
               x_temp = update_state(x_temp, opp_index, Actions_index(j,step));
               % ego car process
               x_temp = update_state(x_temp, car_index, Actions_index(i,step));
               r = r + decay^(step - 1)*reward(x_temp, car_index);
           end
           reward_curr = reward_curr  + r * opp_action_probability(j);
       end
       rewards = [rewards, reward_curr];
   end

   sum_p = 0;

    for i = 1:1:size(rewards,2)
        sum_p = sum_p + exp((rewards(i)));
    end

    for i = 1:1:size(rewards,2)
        action_p_2 = [action_p_2, exp((rewards(i)))/sum_p];
    end


end

function pw = get_pw(x_index, opp_action_index)
 global  dx_set_ego y_set_ego vx_set_ego vy_set_ego vx_set_opp opp_level nw

    x = index_to_state(x_index,dx_set_ego,y_set_ego,  vx_set_ego,...
     vy_set_ego, vx_set_opp,opp_level);
    probability_action = [];
    horizon = 2;
    if x(6) == 1
       %%%%%%%%% important place change into variable after test
       action_p_1 = L_1(x, 2, horizon);
       %%merge probobility for 1 horizon
       %%%%%%%% important place change into variable after test
       probability_action = [sum(action_p_1(1:nw^(horizon - 1))),...
                             sum(action_p_1((nw^(horizon - 1) + 1) : 2*nw^(horizon - 1))),...
                             sum(action_p_1((2*nw^(horizon - 1) + 1) : 3*nw^(horizon - 1)))];
       pw = probability_action(opp_action_index);
    end

    if x(6) == 2
       %%%%%%%%% important place change into variable after test
       action_p_2 = L_2(x, 2, horizon);
       %%merge probobility for 1 horizon
       %%%%%%%% important place change into variable after test
       probability_action = [sum(action_p_2(1:nw^(horizon - 1))),...
                             sum(action_p_2((nw^(horizon - 1) + 1) : 2*nw^(horizon - 1))),...
                            sum(action_p_2((2*nw^(horizon - 1) + 1) : 3*nw^(horizon - 1)))];
       pw = probability_action(opp_action_index);
    end

end

% x = [dx, y, vx, vy, vx_opp, level]

function if_collision = check_if_collision(x)
    global  l_car w_car
    x_traffic = [x(1) 0;
                 x(2) 0];
    l_car_safe = 1.2*l_car;
    w_car_safe = 1.2*w_car;
    x_ego = x_traffic(1, 1);
    y_ego = x_traffic(2, 1);
    theta_ego = 0;

    Ego_rectangle = [x_ego-l_car_safe/2*cos(theta_ego)+w_car_safe/2*sin(theta_ego), y_ego-l_car_safe/2*sin(theta_ego)-w_car_safe/2*cos(theta_ego);
        x_ego-l_car_safe/2*cos(theta_ego)-w_car_safe/2*sin(theta_ego), y_ego-l_car_safe/2*sin(theta_ego)+w_car_safe/2*cos(theta_ego);
        x_ego+l_car_safe/2*cos(theta_ego)-w_car_safe/2*sin(theta_ego), y_ego+l_car_safe/2*sin(theta_ego)+w_car_safe/2*cos(theta_ego);
        x_ego+l_car_safe/2*cos(theta_ego)+w_car_safe/2*sin(theta_ego), y_ego+l_car_safe/2*sin(theta_ego)-w_car_safe/2*cos(theta_ego)];

    x_opp = x_traffic(1, 2);
    y_opp = x_traffic(2, 2);
    theta_opp = 0;

    opp_rectangle = [x_opp-l_car_safe/2*cos(theta_opp)+w_car_safe/2*sin(theta_opp), y_opp-l_car_safe/2*sin(theta_opp)-w_car_safe/2*cos(theta_opp);
            x_opp-l_car_safe/2*cos(theta_opp)-w_car_safe/2*sin(theta_opp), y_opp-l_car_safe/2*sin(theta_opp)+w_car_safe/2*cos(theta_opp);
            x_opp+l_car_safe/2*cos(theta_opp)-w_car_safe/2*sin(theta_opp), y_opp+l_car_safe/2*sin(theta_opp)+w_car_safe/2*cos(theta_opp);
            x_opp+l_car_safe/2*cos(theta_opp)+w_car_safe/2*sin(theta_opp), y_opp+l_car_safe/2*sin(theta_opp)-w_car_safe/2*cos(theta_opp)];

    if isintersect(Ego_rectangle', opp_rectangle')
       if_collision = 1;
    else
       if_collision = 0;
    end
end

%x = [dx_ego, y_ego,vx_ego, vy_ego, vx_opp, opp_level];
function R = reward(x, car_index)
   global Goal l_car w_car
   x_traffic = [x(1) 0;
                x(2) 0];
   R_collision = 0;
   l_car_safe = 1.2*l_car;     % 1.1
   w_car_safe = 1.2*w_car;
   x_ego = x_traffic(1, car_index);
   y_ego = x_traffic(2, car_index);
   theta_ego = 0;

   Ego_rectangle = [x_ego-l_car_safe/2*cos(theta_ego)+w_car_safe/2*sin(theta_ego), y_ego-l_car_safe/2*sin(theta_ego)-w_car_safe/2*cos(theta_ego);
        x_ego-l_car_safe/2*cos(theta_ego)-w_car_safe/2*sin(theta_ego), y_ego-l_car_safe/2*sin(theta_ego)+w_car_safe/2*cos(theta_ego);
        x_ego+l_car_safe/2*cos(theta_ego)-w_car_safe/2*sin(theta_ego), y_ego+l_car_safe/2*sin(theta_ego)+w_car_safe/2*cos(theta_ego);
        x_ego+l_car_safe/2*cos(theta_ego)+w_car_safe/2*sin(theta_ego), y_ego+l_car_safe/2*sin(theta_ego)-w_car_safe/2*cos(theta_ego)];

    for car_id = 1:1:size(x_traffic,2)
        if car_id == car_index
            continue;
        end
        x_opp = x_traffic(1, car_id);
        y_opp = x_traffic(2, car_id);
        theta_opp = 0;

        opp_rectangle = [x_opp-l_car_safe/2*cos(theta_opp)+w_car_safe/2*sin(theta_opp), y_opp-l_car_safe/2*sin(theta_opp)-w_car_safe/2*cos(theta_opp);
            x_opp-l_car_safe/2*cos(theta_opp)-w_car_safe/2*sin(theta_opp), y_opp-l_car_safe/2*sin(theta_opp)+w_car_safe/2*cos(theta_opp);
            x_opp+l_car_safe/2*cos(theta_opp)-w_car_safe/2*sin(theta_opp), y_opp+l_car_safe/2*sin(theta_opp)+w_car_safe/2*cos(theta_opp);
            x_opp+l_car_safe/2*cos(theta_opp)+w_car_safe/2*sin(theta_opp), y_opp+l_car_safe/2*sin(theta_opp)-w_car_safe/2*cos(theta_opp)];
    end

   if isintersect(Ego_rectangle', opp_rectangle')
        R_collision = -100;
    end

   x_ego = x_traffic(1, car_index);
   y_ego = x_traffic(2, car_index);
   R_distance = 0;
   goal = Goal;
   R_distance = -1 * (abs(x_ego - goal(1)) + 4 * abs(y_ego - goal(2)));
   R = R_distance + R_collision;
end


%% calculate the receding horizon cost
function Cost = Cost(Gamma)
global pi_t0 N Px Cost_vec nx nu

Cost = 0;
pi_pre = zeros(nx,N+1);
pi_pre(:,1) = pi_t0;
for tau=1:1:N
    pi_pre(:,tau+1) = (Gamma((tau-1)*nu+1)*Px{1} + Gamma((tau-1)*nu+2)*Px{2} ...
    + Gamma((tau-1)*nu+3)*Px{3} + Gamma((tau-1)*nu+4)*Px{4} +  Gamma((tau-1)*nu+5)*Px{5}...
       + Gamma((tau-1)*nu+6)*Px{6} + Gamma((tau-1)*nu+7)*Px{7} + Gamma((tau-1)*nu+8)*Px{8}...
         + Gamma((tau-1)*nu+9)*Px{9}) * pi_pre(:,tau);

    Cost = Cost + pi_pre(:,tau+1)'*Cost_vec;
end

end

function violation_indices = const(X)
global nx
    violation_indices = [];
    for i = 1:1:nx
        if check_if_collision(X(:,i)) == 1
            violation_indices = [violation_indices, i];
        elseif abs(X(1,i)) <= 7 && X(2,i) == 0
            violation_indices = [violation_indices, i];
        end
    end
end

function cost_vector = cost(X)
  %% important : change goal later
   cost_vector = -8*X(1,:) + X(2,:);

end




function [Const,Ceq] = Const(Gamma)
    global pi_t0 N Px Violation_indices nx nu confidence_level

    pi_pre = zeros(nx,N+1);
    pi_pre(:,1) = pi_t0;
    Prob_violation = 0;
    for(tau=1:1:N)
        pi_pre(:,tau+1) = (Gamma((tau-1)*nu+1)*Px{1} + Gamma((tau-1)*nu+2)*Px{2} ...
     + Gamma((tau-1)*nu+3)*Px{3} + Gamma((tau-1)*nu+4)*Px{4} +  Gamma((tau-1)*nu+5)*Px{5}...
       + Gamma((tau-1)*nu+6)*Px{6} + Gamma((tau-1)*nu+7)*Px{7} + Gamma((tau-1)*nu+8)*Px{8}...
         + Gamma((tau-1)*nu+9)*Px{9}) * pi_pre(:,tau);
        Prob_violation = Prob_violation + sum(pi_pre(Violation_indices,tau+1));
        pi_pre(Violation_indices,tau+1) = 0;
    end

    Const = Prob_violation - (1-confidence_level);
    Ceq = [];
end

function pi_t1 = Bayesian(pi_t0, y_index_t1, u_index_t0)
    global nx Px Py

    Px_k = zeros(nx,1);
    for k = 1:nx
        Px_k(k,1) = Px{u_index_t0}(k,:) * pi_t0;
    end

    De = Py(y_index_t1,:)*Px_k;
    Nu = Py(y_index_t1,:)'.*(Px{u_index_t0}*pi_t0);

    pi_t1 = Nu/De;

end
