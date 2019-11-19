%% Autonomous Overtaking
function main
close all;clear all
% World
global Dt a_hat w_hat Dx Dvx Dy u w v nx nu Cost_vec Violation_indices confidence_level n_1 n_2 ...
    count
count = 0; % Count number of iterations

Dt = 1; % delta t
a_hat = 2; % acceleration value
w_hat = 3.2; % delta y

n_1 = 2; % number of time steps for lane change
n_2 = 10; % length of lane
n_3 = 4; % number of speed values

Dx = [-n_2*a_hat*Dt^2:0.5*a_hat*Dt^2:n_2*a_hat*Dt^2];
Dvx = [-n_3*a_hat*Dt:0.5*a_hat*Dt:n_3*a_hat*Dt];
Dy = [0:w_hat/n_1:w_hat];

u = [[0;0] [a_hat;0] [-a_hat;0] [0;w_hat/(n_1*Dt)] [0;-w_hat/(n_1*Dt)]];

w = [-a_hat:a_hat:a_hat];
Pw = [0.2 0.6 0.2];
v = [[0;0] [0;0.5*a_hat*Dt] [0;-0.5*a_hat*Dt]... 
    [0.5*a_hat*Dt^2;0] [0.5*a_hat*Dt^2;0.5*a_hat*Dt] [0.5*a_hat*Dt^2;-0.5*a_hat*Dt] ...
    [-0.5*a_hat*Dt^2;0] [-0.5*a_hat*Dt^2;0.5*a_hat*Dt] [-0.5*a_hat*Dt^2;-0.5*a_hat*Dt]];
Pv = [0.6 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05];

n_Dx = length(Dx)
n_Dvx = length(Dvx)
n_Dy = length(Dy)

nx = n_Dx*n_Dvx*n_Dy
nu = 5;
nw = length(w)
ny = nx
nv = length(v(1,:))

DX = index_to_state([1:1:nx],Dx,Dvx,Dy); % Full state space values
Cost_vec = cost(DX)'; 
Violation_indices = const(DX)';

confidence_level = 0.95;

% Markov Chain
Px = zeros(nx,nx,nu); % eq 10
step = 1;
for(j=1:nx)
    for(k=1:nu)
        for(l=1:nw)
           step
           i=ffunc(j,k,l);
           Px(i,j,k) = Px(i,j,k) + Pw(l);
           step = step+1;
        end
    end
end

Py = zeros(ny,nx); % eq 11
step = 1;
for(j=1:nx)
    for(n=1:nv)
           step
           m=gfunc(j,n);
           Py(m,j) = Py(m,j) + Pv(n);
           step = step+1;
    end
end

Px_full = Px;
Px = cell(nu,1)
for(k=1:1:nu)
Px{k} = sparse(Px_full(:,:,k));
% Px{k} = Px_full(:,:,k);
end
Py = sparse(Py);
save Pxy Px Py

global Px Py pi_t0 N
load Pxy

% % Test
% for(k=1:nu)
%     Px_k = Px(:,:,k);
%     for(j=1:nx)
%         sum(Px_k(:,j))
%     end
% end
% 
% 
% for(j=1:nx)
%     sum(Py(:,j))
% end

iter_max = 50;
Violation_count = 0;
X_all = cell(iter_max,1);% for plot
for(iter=1:1:iter_max)
% Initial Condition
x_0 = [-n_2*a_hat*Dt^2;0;0];
x_t1 = x_0;

car_leader_0 = [0;20;0];
car_follower_0 = car_leader_0 + x_0;
figure(2);hold on
plot(car_leader_0(1),car_leader_0(3),'ro')
plot(car_follower_0(1),car_follower_0(3),'bo')

figure(3);hold on
if(iter==1)
Violation_states = index_to_state(Violation_indices,Dx,Dvx,Dy);
left_bd = min(Violation_states(1,:));
right_bd = max(Violation_states(1,:));
bottom_bd = min(Violation_states(3,:));
top_bd = max(Violation_states(3,:));
% plot(Violation_states(1,:),Violation_states(3,:),'ro')
rectangle('Position',[left_bd,bottom_bd,right_bd-left_bd,top_bd-bottom_bd],'FaceColor','r','EdgeColor','r','LineWidth',1)
end
plot(x_0(1),x_0(3),'b.','MarkerSize',10)
figure(33);hold on
if(iter==1)
rectangle('Position',[left_bd,bottom_bd,right_bd-left_bd,top_bd-bottom_bd],'FaceColor','r','EdgeColor','r','LineWidth',1)
end

x_index_0 = state_to_index(x_0,Dx,Dvx,Dy);
x_index_t1 = x_index_0;
pi_t0 = zeros(nx,1);
pi_t0(x_index_0,1) = 1;
pi_t1 = pi_t0;
car_leader_t1 = car_leader_0;
car_follower_t1 = car_follower_0;

% Sim
N = 5;
Gamma = zeros(nu*N,1);

% Probability constraints
A = [eye(length(Gamma));
    -eye(length(Gamma))];
b = [ones(length(Gamma),1);
    zeros(length(Gamma),1)];

Aeq = [ones(1,nu) zeros(1,length(Gamma)-nu);
    zeros(1,nu) ones(1,nu) zeros(1,length(Gamma)-2*nu);
    zeros(1,2*nu) ones(1,nu) zeros(1,length(Gamma)-3*nu);
    zeros(1,3*nu) ones(1,nu) zeros(1,length(Gamma)-4*nu);
    zeros(1,4*nu) ones(1,nu)];

% Aeq = [ones(1,nu) zeros(1,length(Gamma)-nu);
%     zeros(1,nu) ones(1,nu) zeros(1,length(Gamma)-2*nu);
%     zeros(1,2*nu) ones(1,nu) zeros(1,length(Gamma)-3*nu);
%     zeros(1,3*nu) ones(1,nu) zeros(1,length(Gamma)-4*nu);
%     zeros(1,4*nu) ones(1,nu) zeros(1,length(Gamma)-5*nu);
%     zeros(1,5*nu) ones(1,nu) zeros(1,length(Gamma)-6*nu);
%     zeros(1,6*nu) ones(1,nu) zeros(1,length(Gamma)-7*nu);
%     zeros(1,7*nu) ones(1,nu) zeros(1,length(Gamma)-8*nu);
%     zeros(1,8*nu) ones(1,nu) zeros(1,length(Gamma)-9*nu);
%     zeros(1,9*nu) ones(1,nu)];
beq = ones(N,1);

PI = pi_t1;
X_index = x_index_t1;
X = x_t1;
step = 1;
while(x_t1(1)<n_2*a_hat*Dt^2)
   step
   x_index_t0 = x_index_t1;
   pi_t0 = pi_t1;
   car_leader_t0 = car_leader_t1;
   car_follower_t0 = car_follower_t1;
   
%    options = optimoptions('fmincon','Display','iter','MaxIterations',1);
   Gamma0 = ones(nu*N,1)/nu;
   tic
   count = 0;
   [Gamma, fval] = fmincon(@Cost,Gamma0,A,b,Aeq,beq,[],[],@Const,[]);
   t_sim(step) = toc
   gamma = Gamma(1:nu)

   random = rand();
   sum_rand = 0;
   for(k=1:1:nu)   
       sum_rand = sum_rand+gamma(k);
       if(sum_rand>random)
       u_index_t0 = k;
       break
       end   
   end
   
%    u_index_t0 = randi([1 nu]);
%    w_index_t0 = randi([1 nw]);
%    v_index_t0 = randi([1 nv]);
   
   random = rand();
   sum_rand = 0;
   for(l=1:1:nw)   
       sum_rand = sum_rand+Pw(l);
       if(sum_rand>random)
       w_index_t0 = l;
       break
       end   
   end
   
   random = rand();
   sum_rand = 0;
   for(n=1:1:nv)   
       sum_rand = sum_rand+Pv(n);
       if(sum_rand>random)
       v_index_t0 = n;
       break
       end   
   end
   
   x_index_t1 = ffunc(x_index_t0,u_index_t0,w_index_t0);
   y_index_t1 = gfunc(x_index_t1,v_index_t0);
   pi_t1 = Bayesian(pi_t0,y_index_t1,u_index_t0);
   
   x_index_t1_hat = find(pi_t1 == max(pi_t1))
   x_index_t1
   
   if(ismember(x_index_t1,Violation_indices))
   Violation_count = Violation_count+1;
   end   
   
   x_t1 = index_to_state(x_index_t1,Dx,Dvx,Dy);
   car_leader_t1 = [1 Dt 0;0 1 0;0 0 1]*car_leader_t0+[0;Dt;0]*w(w_index_t0);
   car_follower_t1 = car_leader_t1 + x_t1;
   figure(2);hold on
   plot(car_leader_t1(1),car_leader_t1(3),'ro')
   plot([car_follower_t0(1) car_follower_t1(1)],[car_follower_t0(3) car_follower_t0(3)+u(2,u_index_t0)],'b-')
   plot(car_follower_t1(1),car_follower_t1(3),'bo')
   figure(3);hold on
   plot(x_t1(1),x_t1(3),'b.','MarkerSize',10)
   
   PI = [PI pi_t1];
   X_index = [X_index x_index_t1];
   X = [X x_t1];
   drawnow()
   step = step+1;
   step_max = step;
end

figure(33);hold on
plot(X(1,:),X(3,:),'b-','LineWidth',2)
figure(44);hold on
plot([1:1:step_max],X(2,:),'b-','LineWidth',2)

for(step = 1:step_max)
   x_index_t1_hat = find(PI(:,step)~=0);
   figure(1);hold on
   plot(step+0.*x_index_t1_hat,x_index_t1_hat,'b.')
   plot(step,X_index(step),'ro')
end

X_all{iter} = X;
end

save workspace

return

function x_index_t1 = ffunc(x_index_t0,u_index_t0,w_index_t0)
global Dt a_hat w_hat Dx Dvx Dy u w v
u_t0 = u(:,u_index_t0);
w_t0 = w(w_index_t0);
x_t0 = index_to_state(x_index_t0,Dx,Dvx,Dy);
x_t1 = [1 Dt 0;0 1 0;0 0 1]*x_t0 + [0 0;Dt 0;0 Dt]*u_t0 - [0;Dt;0]*w_t0;
x_index_t1 = state_to_index(x_t1,Dx,Dvx,Dy);
return
               
function y_index_t0 = gfunc(x_index_t0,v_index_t0)
global Dt a_hat w_hat Dx Dvx Dy u w v
v_t0 = v(:,v_index_t0);
x_t0 = index_to_state(x_index_t0,Dx,Dvx,Dy);
y_t0 = x_t0 + [v_t0;0];
y_index_t0 = state_to_index(y_t0,Dx,Dvx,Dy);
return

function x_index = state_to_index(x,x1,x2,x3)

x1_index = dsearchn(x1',x(1,:)');
x2_index = dsearchn(x2',x(2,:)');
x3_index = dsearchn(x3',x(3,:)');

x1_length = length(x1);
x2_length = length(x2);
x3_length = length(x3);

size = [x1_length,x2_length,x3_length];
x_index = sub2ind(size,x1_index,x2_index,x3_index);
return

function x = index_to_state(x_index,x1,x2,x3)

x1_length = length(x1);
x2_length = length(x2);
x3_length = length(x3);

size = [x1_length,x2_length,x3_length];
[x1_index,x2_index,x3_index] = ind2sub(size,x_index);

x = [x1(x1_index);x2(x2_index);x3(x3_index)];
return

function pi_t1 = Bayesian(pi_t0,y_index_t1,u_index_t0)
global nx Px Py

Px_k = zeros(nx,1);
for(k=1:nx)
Px_k(k,1) = Px{u_index_t0}(k,:)*pi_t0;
end

De = Py(y_index_t1,:)*Px_k;

Nu = Py(y_index_t1,:)'.*(Px{u_index_t0}*pi_t0);

pi_t1 = Nu/De;

return

function cost_vec = cost(DX)
global Dt a_hat w_hat
r = 5;

cost_vec = -r/(a_hat*Dt^2)*DX(1,:)+1/w_hat*DX(3,:);
return

function violation_indices = const(DX)
global Dt a_hat w_hat n_1 n_2

% violation_indices = [];
violation_indices = find(DX(3,:)<=(n_1-1)/n_1*w_hat & abs(DX(1,:))<=n_2/2*a_hat*Dt^2);
return

function Cost = Cost(Gamma)
global pi_t0 N Px Cost_vec nx nu count

Cost = 0;
pi_pre = zeros(nx,N+1);
pi_pre(:,1) = pi_t0;
% tic
for(tau=1:1:N)
pi_pre(:,tau+1) = (Gamma((tau-1)*nu+1)*Px{1} + Gamma((tau-1)*nu+2)*Px{2} + Gamma((tau-1)*nu+3)*Px{3} + Gamma((tau-1)*nu+4)*Px{4} + Gamma((tau-1)*nu+5)*Px{5}) * pi_pre(:,tau);

% Cost = Cost + pi_pre(:,tau+1)'*Cost_vec - Gamma((tau-1)*nu+1);
Cost = Cost + pi_pre(:,tau+1)'*Cost_vec;
end  
% toc
count = count + 1;
return

function [Const,Ceq] = Const(Gamma)
global pi_t0 N Px Violation_indices nx nu confidence_level 

pi_pre = zeros(nx,N+1);
pi_pre(:,1) = pi_t0;
Prob_violation = 0;
for(tau=1:1:N)
pi_pre(:,tau+1) = (Gamma((tau-1)*nu+1)*Px{1} + Gamma((tau-1)*nu+2)*Px{2} + Gamma((tau-1)*nu+3)*Px{3} + Gamma((tau-1)*nu+4)*Px{4} + Gamma((tau-1)*nu+5)*Px{5}) * pi_pre(:,tau);

Prob_violation = Prob_violation + sum(pi_pre(Violation_indices,tau+1));
pi_pre(Violation_indices,tau+1) = 0;
end  

Const = Prob_violation - (1-confidence_level);
Ceq = [];
return 
