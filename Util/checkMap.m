function s = checkMap(H, checkComplex)
% function to check the consistency of the Map H, including specialized
% checks for LinOps
% returns a stats object with information about which tests passed

% default values
if ~exist('checkComplex', 'var') || isempty(checkComplex)
	checkComplex = false;
end

fprintf('-- Checking Map with name %s--\n', H.name);

% create inputs to use for checking methods
if ~isnumeric(H.sizein) || ~isnumeric(H.sizeout)
	fprintf('H dimensions are not set, cannot do automatic testing\n');
	return;
end

x = randn([H.sizein 1]);
y = randn([H.sizeout 1]);

if checkComplex
	x = x + 1i * randn([H.sizein 1]);
	y = y + 1i * randn([H.sizeout 1]);
end

% get the metaclass obj used to check for HtH and HHt
meta = metaclass(H);


% apply
try
	Hx = H.apply(x);
	s.applyOK = true;
	fprintf('apply OK\n');
catch ME
	fprintf('apply FAILs:\n\t%s\n', ME.message');
	s.applyOK = false;
end

% applyJacobianT
if H.isDifferentiable
	try
		H.applyJacobianT(y, x);
		s.applyJacobianTOK = true;
		fprintf('applyJacobianT OK\n');
	catch ME
		fprintf('H.isDifferentiable, but applyJacobianT FAILs:\n\t%s\n', ME.message);
		s.applyJacobianTOK = false;
	end
end

% applyInverse
if H.isInvertible
	try
		xhat = H.applyInverse(Hx);
		s.applyInverseOK = true;
		fprintf('applyInverse OK\n');
	catch ME
		s.applyInverseOK = false;
		fprintf('H.isInvertible, but applyInverse FAILs:\n\t%s\n', ME.message);
	end
	
	if s.applyOK && s.inverseOK
		curSNR = snr(x, x-xhat);
		s.applyInverseOK = checkSNR(curSNR);
	else
		fprintf('\tcannot assess accuracy\n');
	end
end




if isa(H, 'LinOp')
	fprintf('-- LinOp-specific checks --\n')
	
	% adjoint
	try
		HTy = H.applyAdjoint(y);
		s.applyAdjointOK = true;
		fprintf('applyAdjoint OK\n');
	catch ME
		fprintf('applyAdjoint fails:\n\t%s\n', ME.message');
		s.applyAdjointOK = false;
	end
	
	if s.applyOK && s.applyAdjointOK
		lhs = x(:)' * HTy(:);
		rhs = Hx(:)' * y(:);
		curSNR = snr(lhs, lhs-rhs);
		checkSNR(curSNR);
	else
		fprintf('\tcannot assess accuracy\n');
	end
	
	% HtH
	if ~strcmp(getDefiningClass('applyHtH_', meta), 'LinOp') % if applyHtH is implemented
		try
			HTHx = H.applyHtH(x);
			s.applyHtHOK = true;
			fprintf('applyHtH OK\n');
		catch ME
			fprintf('applyHtH fails:\n\t%s\n', ME.message');
			s.applyHtHOK = false;
		end
		
		if s.applyOK && s.applyAdjointOK && s.applyHtHOK
			lhs = HTHx;
			rhs = H.applyAdjoint( Hx );
			curSNR = snr(lhs, lhs-rhs);
			checkSNR(curSNR);
		else
			fprintf('\tcannot assess accuracy\n');
		end
	else
		fprintf('applyHtH not implemented\n');
	end
	
	% HHt
	if ~strcmp(getDefiningClass('applyHHt_', meta), 'LinOp') % if applyHHt is implemented
		try
			HHty = H.applyHHt(y);
			s.applyHHtOK = true;
			fprintf('applyHHt OK\n');
		catch ME
			fprintf('applyHHt fails:\n\t%s\n', ME.message');
			s.applyHHtOK = false;
		end
		
		if s.applyOK && s.applyAdjointOK && s.applyHHtOK
			lhs = HHty;
			rhs = H.apply( HTy );
			curSNR = snr(lhs, lhs-rhs);

			checkSNR(curSNR);
		else
			fprintf('\tcannot assess accuracy\n');
		end
	else
		fprintf('applyHHt not implemented\n');
	end

end

end

function isOK = checkSNR(snr)
isOK = snr > 70;
if isOK
	okString = 'OK';
else
	okString = 'FAIL';
end
fprintf('\tSNR: %.3g dB, %s\n', snr, okString)
end

function className = getDefiningClass(methodName, meta)
ind = strcmp( {meta.MethodList.Name}, methodName);
className = meta.MethodList(ind).DefiningClass.Name;
end