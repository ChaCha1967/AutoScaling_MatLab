function [outStruct, FV, HT, QQ, N] = polan_fortran_exact(fv_in, ht_in, fb, dip, start_val, amode, valley, list_flag)
% POLAN_FORTRAN_EXACT Exact 1-to-1 line-by-line MATLAB translation of Titheridge's
% Fortran-77 POLAN source files: polan.f, polsin.f, polsub.f, and polmis.f.
%
% Inputs:
%   fv_in     : Vector of sounding frequencies (MHz). Positive for O-ray, negative for X-ray.
%   ht_in     : Vector of virtual heights h'(f) (km).
%   fb        : Electron gyrofrequency at ground (MHz), e.g., 1.40 (negative = constant with height)
%   dip       : Magnetic dip angle (degrees), e.g., 80.0
%   start_val : Start parameter (0.0 = default extrapolation, >=45 = model start height in km)
%   amode     : Mode of analysis (0.0 = default mode 6/16, 1..10 = polynomial order)
%   valley    : Valley flag (0.0 = standard valley, 10.0 = monotonic / no valley)
%   list_flag : Debug print level (default = 0; >0 prints trace to command window)
%
% Outputs:
%   outStruct : Structure with real heights, peak parameters (foF2, hmF2, SH, TEC), and topside
%   FV, HT    : Raw Fortran-equivalent in-place output arrays (length NDIM = 399)
%   QQ        : Polynomial coefficient & peak summary array (length 50)
%   N         : Final output index returned by SUBROUTINE POLAN

    if nargin < 3 || isempty(fb),        fb = 1.40;       end
    if nargin < 4 || isempty(dip),       dip = 80.0;      end
    if nargin < 5 || isempty(start_val), start_val = 0.0; end
    if nargin < 6 || isempty(amode),     amode = 0.0;     end
    if nargin < 7 || isempty(valley),    valley = 10.0;   end
    if nargin < 8 || isempty(list_flag), list_flag = 0;   end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Add terminator 0 to hv_in array. My addon
    if ht_in(end)>=10
        fv_in = [fv_in(:); fv_in(end) + 0.05];
        ht_in = [ht_in(:); 0.0];
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    NDIM = 399;
    FV = zeros(NDIM, 1);
    HT = zeros(NDIM, 1);
    QQ = zeros(50, 1);
    QQ(1) = 1.0;

    K_in = numel(fv_in);
    if K_in + 46 > NDIM
        NDIM = K_in + 60;
        FV = zeros(NDIM, 1);
        HT = zeros(NDIM, 1);
    end

    FV(1:K_in) = double(fv_in(:));
    HT(1:K_in) = double(ht_in(:));

    if FV(K_in) > 0.0 && HT(K_in) > 0.0
        FV(K_in + 1) = 0.0; HT(K_in + 1) = 0.0;
        FV(K_in + 2) = 0.0; HT(K_in + 2) = 0.0;
    end

    N = NDIM;
    [N, FV, HT, QQ, P] = sub_polan(N, FV, HT, QQ, double(fb), double(dip), ...
                                   double(start_val), double(amode), double(valley), round(list_flag));
    outStruct = unpack_polan_arrays(N, FV, HT, QQ, fv_in, ht_in, P);
end

function out = unpack_polan_arrays(N, FV, HT, QQ, fv_in, ht_in, P)
    out = struct();
    out.N_out  = N;
    out.QQ     = QQ;
    out.f_virt = double(fv_in(:));
    out.h_virt = double(ht_in(:));

    if N >= 5 && FV(N - 3) > 0 && HT(N - 3) > 50
        out.f_real    = FV(1 : N - 3);
        out.h_real    = HT(1 : N - 3);
        out.foF2      = FV(N - 3);
        out.hmF2      = HT(N - 3);
        out.f_topside = FV(N - 2 : N);
        out.h_topside = HT(N - 2 : N);
        out.dev_f     = FV(N + 1);
        out.dev_h     = HT(N + 1);
        out.TEC       = FV(N + 2);
        out.H_scale   = abs(HT(N + 2));
        out.status    = 'OK';
    else
        valid_r = max(1, P.KR);
        out.f_real    = FV(1 : valid_r);
        out.h_real    = HT(1 : valid_r);
        out.foF2      = P.FC;
        out.hmF2      = P.HMAX;
        out.f_topside = [];
        out.h_topside = [];
        out.dev_f     = NaN;
        out.dev_h     = NaN;
        out.TEC       = P.tcont * 0.124;
        out.H_scale   = abs(P.SH);
        out.status    = 'ERROR_EXIT';
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    out.f_real_all = [out.f_real; out.foF2; out.f_topside];
    out.h_real_all = [out.h_real; out.hmF2; out.h_topside];
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    out.Ne_cm3 = 1.24e4 .* (out.f_real .^ 2);
end

function P = init_common_pol()
    P = struct();
    P.B      = zeros(99, 20);
    P.Q      = zeros(20, 1);
    P.FH     = 0.0;
    P.ADIP   = 0.0;
    P.MODE   = 0;
    P.MOD    = 0;
    P.FA     = 0.0;
    P.HA     = 0.0;
    P.tcont  = 0.0;
    P.lbug   = 0;
    P.HS     = 0.0;
    P.FC     = 0.0;
    P.FCC    = 0.0;
    P.HMAX   = 0.0;
    P.SH     = 0.0;
    P.PARHT  = 0.0;
    P.HVAL   = 0.0;
    P.VWIDTH = 0.0;
    P.VDEPTH = 0.0;
    P.XWAT   = 0.0;
    P.MAXB   = 98;
    P.NF     = 0;
    P.NR     = 0;
    P.NL     = 0;
    P.NX     = 0;
    P.MS     = 0;
    P.MT     = 0;
    P.JM     = 0;
    P.LK     = 0;
    P.KR     = 0;
    P.KRM    = 0;
    P.KV     = 0;
    P.MF     = 0;
    P.NC     = 0;

    P.solve_NQ    = 0;
    P.solve_NP    = 0;
    P.solve_WSETQ = zeros(17, 1);
    P.solve_VSETQ = zeros(17, 1);

    P.staval_VAL   = 0.0;
    P.staval_DVAL  = 0.0;
    P.staval_DEVL  = 0.0;
    P.staval_DEVLL = 0.0;
    P.staval_HDEC  = 0.0;
    P.staval_FHHT  = 0.0;

    P.gind_GH    = 0.0;
    P.gind_GHSN  = 0.0;
    P.gind_GCSCT = 0.0;
    P.gind_FH    = 0.0;
    P.gind_FHSN  = 0.0;
    P.gind_FCSCT = 0.0;
    P.gind_HFH   = 0.0;
    P.gind_C     = 0.0;
    P.gind_C2    = 0.0;

    P.coefic_FTC = 0.0;
end

function [N, FV, HT, QQ, P] = sub_polan(N, FV, HT, QQ, fb, dip, start, amode, valley, list)
    P = init_common_pol();

    IT = [1, 2, 3, 4, 4, 5, 6, 6, 6, 73, 1, 2, 3, 4, 5, 6, 6, 6, 6, 73];
    IV = [1, 2, 3, 4, 5, 7, 8, 10, 12, 90, 1, 1, 2, 3, 4, 5, 7, 8, 13, 90];
    IR = [0, 0, 0, 1, 1, 2, 2, 3, 5, 2, 0, -1, -1, 1, -2, -3, -3, -4, -6, -3];
    IH = [1, 1, 2, 3, 3, 4, 5, 6, 8, 28, 1, 1, 1, 1, 1, 1, 2, 2, 3, 28];

    tcontf = @(fa, x, j) (fa * (fa / j + 2.0 * x / (j + 1.0)) + (x * x) / (j + 2.0)) * (x ^ j);

    P.MAXB = 98;
    ndim = max(N, 100);
    if QQ(1) ~= -1.0
        QQ(1) = 1.0;
    end
    FV(ndim - 45) = -1.0;
    HT(ndim - 45) = 0.0;

    P.ADIP = max(abs(dip), 0.001);
    [P.FH, P] = fn_gind(fb, -P.ADIP, P);
    P.lbug = list;
    if P.lbug > 7
        P.lbug = -P.lbug;
    end
    if P.lbug > 1
        sub_trace(FV, HT, 0.0, P);
    end

    P.MODE = fix(abs(amode));
    if P.MODE == 0
        P.MODE = 6 + fix(P.ADIP / 60.0) * 10;
    end
    MODB = 0;
    if P.MODE >= 30
        MODB = fix(P.MODE / 10);
    end
    moda = P.MODE - MODB * 10;
    MODC = 0;
    if MODB >= 30
        MODC = fix(MODB / 10);
    end
    MODB = MODB - MODC * 10;
    if moda == 0, moda = MODB; end
    if MODB == 0, MODB = moda; end
    if MODC == 0, MODC = MODB; end
    mod1 = moda - fix(moda / 10) * 10;
    if P.MODE == 10 || P.MODE >= 30
        mod1 = 10;
    end

    [FV, HT, P] = sub_setup(FV, HT, ndim, start, P);

    DHS = max(P.HA - P.HS, 0.0);

    state = 200;
    tras  = 0.0;
    devn  = 0.0;
    NV    = 0;
    NT    = 0;
    NH    = 0;
    MSA   = 0;
    FM    = 0.0;
    MV    = 0;
    NNR   = 0;

    while true
        switch state
            case 200
                P.MOD = mod1;
                P.KRM = P.KR;
                NNR   = 0;
                state = 230;

            case 210
                if P.MOD <= 10
                    P.KR  = P.KR - IR(P.MOD);
                    P.KV  = P.KV - IR(P.MOD);
                    P.MOD = P.MOD + 10;
                end
                NNR   = IR(P.MOD);
                state = 230;

            case 230
                NT   = IT(P.MOD);
                NV   = IV(P.MOD);
                NH   = IH(P.MOD);
                P.NR = abs(NNR);
                P.NL = min(1, P.NR - NNR);
                P.MS = 0;
                MSA  = 0;
                if P.LK == 1 && (P.KV == 43 || P.KV == 29) && amode >= 0.0
                    MSA = 1;
                end
                if NV > 1 && NV < 8
                    NV = NV - MSA;
                end

                [NV, FV, HT, P] = sub_seldat(NV, FV, HT, P);
                tras = -2.2;
                if NV < 0
                    state = 730;
                    continue;
                end
                FM = FV(P.MF);
                MV = P.MF - P.KV;
                if P.NF > NV
                    NH = NH + fix((P.NF - NV) / 2);
                end
                if P.FCC > 0.0 && P.lbug == -8
                    P.lbug = 8;
                end
                if P.lbug > 2 || (P.lbug == 2 && P.MOD < 10)
                    sub_trace(FV, HT, 2.2, P);
                end
                if P.KR == 1
                    state = 300;
                    continue;
                end

                [FV, HT, P] = sub_reduce(FV, HT, P);
                MV   = P.MF - P.KV;
                tras = -2.3;
                if P.JM <= 0
                    state = 740;
                    continue;
                end
                if P.lbug > 2
                    sub_trace(FV, HT, 2.3, P);
                end
                state = 300;

            case 300
                P.MT = NT;
                if NT > 20
                    P.MT = round(2.0 * sqrt(double(P.NF)));
                end
                if P.LK < 0 || P.HVAL ~= 0.0
                    P.MT = P.MT + 1;
                end
                if P.NX > 0
                    P.MT = P.MT + fix(P.NX / 3);
                end
                if P.NF > NV
                    P.MT = P.MT + fix((P.NF - NV) / 3);
                end
                if P.MODE >= 30
                    P.MT = moda;
                    if P.KR > 1
                        P.MT = MODB;
                    end
                    if FV(P.MF + 2) == 0.0 || P.NF >= NV
                        P.MT = MODC;
                    end
                end
                P.MT = min([14, P.MT, MV + P.NR + MSA]);
                P.JM = P.MT;
                P.FA = FV(P.KR);
                P.HA = HT(P.KR);
                P.NC = 0;

                LOOP = 0;
                [FV, HT, LOOP, P] = sub_staval(FV, HT, dip, valley, LOOP, P);
                if P.HVAL ~= 0.0 && amode >= 0.0
                    P.MT = P.MT + max(fix((9 - P.MT) / 3), 0);
                end
                if P.LK <= 0 || P.HVAL ~= 0.0
                    P.JM = P.MT + 1;
                end
                if P.lbug > 3
                    sub_trace(FV, HT, 3.1, P);
                end
                state = 330;

            case 330
                [FV, HT, P] = sub_coefic(MV, FV, HT, P);
                tras = -3.2;
                if P.JM <= 0
                    state = 740;
                    continue;
                end
                if ~(amode < 0.0 || MV + 4 > P.MAXB)
                    if MSA == 1
                        idx_interp = 44;
                        G = 1.0 + 1.8 / FV(idx_interp);
                        P.B(MV + 1, 1)        = 0.5;
                        P.B(MV + 1, P.JM + 1) = 0.5 * G * (HT(idx_interp) - P.HA);
                        P.MS = 1;
                    end
                    if P.LK < 0
                        WS = 0.1;
                        if start > 44.0, WS = 0.3; end
                        P.B(MV + 1, P.JM)     = -WS;
                        P.B(MV + 1, P.MT)     = 0.25 * WS;
                        P.B(MV + 1, P.JM + 1) = DHS * 0.25 / (P.FA^2) * WS;
                        P.B(MV + 2, P.MT)     = WS * 0.3;
                        P.B(MV + 2, P.JM + 1) = (P.HS / 2.0 - 40.0) / (P.FA^2) * WS * 0.3;
                        P.B(MV + 3, P.MT - 1) = WS * 0.15;
                        P.MS = 3;
                    elseif P.HVAL ~= 0.0
                        WV = 1.0;
                        if P.HVAL < -2.0, WV = 10.0; end
                        if P.NX > 0,      WV = 0.2;  end
                        P.B(MV + 1, P.JM)     = WV;
                        P.B(MV + 1, P.JM + 1) = (P.VWIDTH - P.PARHT) * WV;
                        P.B(MV + 2, P.MT)     = 0.5;
                        P.B(MV + 3, 1)        = 0.4;
                        P.B(MV + 3, P.JM)     = -0.1 / P.VDEPTH;
                        P.B(MV + 4, P.MT - 1) = 0.15;
                        P.MS = min(4, P.MT);
                    end
                end

                P.NC = P.NC + 1;
                if P.lbug > 2 || (P.MS > 0 && P.lbug ~= 0)
                    sub_trace(FV, HT, 3.3, P);
                end

                NS = min(MV + P.NR + P.MS, P.MAXB);
                [NS, P.B, P.Q, devn, P] = sub_solve(NS, P.JM, P.B, P.Q, 0.0, devn, P.lbug, P);
                tras = 4.1;
                if NS < P.JM
                    state = 720;
                    continue;
                end

                if MSA == 1,  P.lbug = P.lbug + 200; end
                if dip < 0.0, P.lbug = P.lbug + 400; end
                [P.B, P.Q, P.lbug, P] = sub_adjust(P.HA, P.FA, FM, P.FCC, P.LK, P.JM, P.MT, P.B, P.Q, P.lbug, P);

                LOOP = 2;
                if P.JM ~= P.MT && P.NX <= 0
                    P.VWIDTH = P.Q(P.JM) + P.PARHT;
                    if P.NC == 1 && P.HVAL ~= 0.0
                        LOOP = 1;
                    end
                end
                if (P.lbug > 1 && P.HVAL ~= 0.0) || P.lbug > 2
                    sub_trace(FV, HT, 4.3, P);
                end
                if fb < 0.0
                    LOOP = -abs(LOOP);
                end
                if P.JM > P.MT
                    [FV, HT, LOOP, P] = sub_staval(FV, HT, start, valley, LOOP, P);
                end
                if LOOP == 4
                    state = 330;
                    continue;
                end
                if LOOP == 3 && fb > 0.0
                    state = 330;
                    continue;
                end

                P.KRM = P.KR + P.NR - P.NL;
                KVM   = P.KV + P.NR - P.NL;
                FL    = FV(KVM);
                NH    = min(NH, P.NF - fix(mod1 / 10) * 2);
                MQ    = P.MT + min(P.LK, 0);
                KA    = KVM + 1;

                for K = KA : P.MF
                    FR        = FV(K);
                    P.KRM     = P.KRM + 1;
                    DELTF     = FR - P.FA;
                    FV(P.KRM) = FR;
                    HT(P.KRM) = P.HA + fn_sumval(MQ, P.Q, DELTF, 1);
                end

                FN = FV(KVM + NH);
                if P.FCC ~= 0.0
                    NH = P.KRM - P.KR;
                    FN = FM;
                end
                for J = 1 : MQ
                    P.tcont = P.tcont + J * P.Q(J) * (tcontf(P.FA, FN - P.FA, J) - tcontf(P.FA, FL - P.FA, J));
                end

                P.KR = P.KR + NH;
                P.KV = P.KV + NH;
                if P.FCC == 0.0
                    state = 210;
                    continue;
                end
                if abs(P.FCC - (-0.1)) < 1e-6
                    state = 200;
                    continue;
                end
                P.FC = P.FCC;

                if QQ(1) >= 1.0
                    numq = fix(QQ(1)) + 4;
                    skip_store = false;
                    for j = (numq - 3) : (numq + MQ)
                        if j <= numel(QQ) && QQ(j) == -1.0
                            skip_store = true;
                            break;
                        end
                        if j >= numq && j <= numel(QQ)
                            QQ(j) = P.Q(j - numq + 1);
                        end
                    end
                    if ~skip_store
                        QQ(numq - 3) = P.FA;
                        QQ(numq - 2) = P.HA;
                        QQ(numq - 1) = MQ;
                        numq = numq + MQ;
                        QQ(numq) = devn;
                        if P.FCC < 0.0
                            numq = numq + 1;
                            if QQ(numq) ~= -1.0
                                QQ(numq) = FM;
                            end
                        end
                        QQ(1) = numq;
                    end
                end

                tras = 6.0;
                if P.FCC < 0.0
                    state = 760;
                    continue;
                end
                if HT(P.KRM) < 70.0
                    state = 740;
                    continue;
                end
                [FV, HT, QQ, P] = sub_peak(FV, HT, QQ, P);

                if P.lbug ~= -10
                    P.lbug = abs(P.lbug);
                end
                if P.lbug == 8
                    P.lbug = -8;
                end
                P.HS = (P.HMAX + HT(P.KRM)) / 2.0;
                if HT(P.KV + 1) > 0.0
                    state = 200;
                    continue;
                end

                N = P.KR + 3;
                FV(N - 2) = P.FC * 0.98642;
                FV(N - 1) = P.FC * 0.93300;
                FV(N)     = P.FC * 0.83462;
                HT(N - 2) = P.HMAX + P.SH * 0.3565;
                HT(N - 1) = P.HMAX + P.SH * 0.8878;
                HT(N)     = P.HMAX + P.SH * 1.6216;
                FV(N + 2) = P.tcont * 0.124;
                HT(N + 2) = P.SH;
                FV(N + 3) = 0.0;
                HT(N + 3) = 0.0;
                NUMQ = fix(QQ(1)) + 1;
                if NUMQ > 1 && NUMQ <= numel(QQ)
                    QQ(NUMQ) = -99.0;
                end
                return;

            case 720
                if P.FC == -1.0
                    state = 760;
                else
                    state = 730;
                end

            case 730
                if NV < 0
                    P.KV = -NV - 1;
                end
                state = 740;

            case 740
                if P.lbug ~= -10
                    idx_err = max(1, P.KV - 1) : min(numel(FV), P.KV + 4);
                    fprintf('>>>>>error at f,h =');
                    for ii = idx_err
                        fprintf('%7.2f%7.2f', FV(ii), HT(ii));
                    end
                    fprintf(' section%4.1f%5d  >>>> end\n\n', tras, P.KV);
                    sub_trace(FV, HT, tras, P);
                end
                state = 760;

            case 760
                N = P.KR + 1;
                FV(N)     = FV(P.KV + 1);
                HT(N)     = HT(P.KV + 1);
                FV(N + 1) = 0.0;
                HT(N + 1) = 0.0;
                lq = fix(QQ(1)) + 1;
                if lq > 1 && lq <= numel(QQ) && QQ(lq) ~= -1.0
                    QQ(lq) = -98.0;
                end
                return;
        end
    end
end

function [FV, HT, P] = sub_setup(FV, HT, NDIM, START, P)
    P.VDEPTH = 0.0;
    P.VWIDTH = 0.0;
    P.tcont  = 0.0;
    P.SH     = 0.0;
    P.FC     = 0.0;

    J = 1;
    for K = (NDIM - 44) : -1 : 1
        FV(K + 44) = FV(K);
        HT(K + 44) = HT(K);
        if FV(K) > 0.0
            J = K;
        end
    end

    while true
        FMIN = FV(J);
        if J > 1
            FMIN = min(FMIN, sqrt(FV(1) * (FV(1) + 0.9 * P.FH)));
        end

        HMIN = HT(J);
        I_loop_completed = true;
        I_val = 1;
        for I = 1 : 5
            I_val = I;
            if HT(J + I) < 45.0
                I_loop_completed = false;
                break;
            end
            HMIN = min(HMIN, HT(J + I));
        end
        if I_loop_completed
            I_val = 6;
        end

        P.HA = HMIN;
        P.FA = FMIN;
        P.HS = P.HA;
        JS   = 0;
        P.LK = 1;

        if START < 0.0 && START >= -1.0 && J == 1
            break;
        end

        h1max = min(HMIN + 40.0, HT(2) + 200.0 * (FV(2) - FV(1)));
        if J == 1 && HT(1) > h1max && I_val > 4
            for ii = 1 : 43
                FV(ii) = FV(ii + 1);
                HT(ii) = HT(ii + 1);
            end
            continue;
        end

        JS = 2;
        if FV(J + 2) > 0.0
            DH = abs(HT(J + 2) - HT(J)) * FMIN / (FV(J + 2) - FMIN);
        else
            DH = HT(J) / 6.0;
        end
        if FV(J + 2) <= 0.0 || HT(J + 2) <= 0.0
            DH = HT(J) / 6.0;
        end
        P.HS = min(HMIN - DH, HMIN / 2.0 + 50.0);
        P.HS = max(P.HS, HMIN / 4.0 + 55.0);
        P.FA = min(0.5, 0.6 * FMIN);

        if abs(START) >= 45.0
            P.HS = min(abs(START), P.HS * 0.4 + HMIN * 0.6);
        end
        if J <= 1
            P.HA = P.HS;
            if P.MODE == 10 || P.MODE >= 20
                P.FA = FMIN * 0.6;
            end
            if START >= 45.0 || START == 0.0
                break;
            end
            H_val = fix(START * 0.1) * 10.0;
            P.HA  = 90.0 + H_val + H_val;
            P.FA  = START - H_val;
            break;
        else
            JS   = 1;
            P.HA = P.HS * 0.4 + HMIN * 0.6;
            P.LK = 0;
            if START > -3.0
                P.FA = -START - 1.0;
            end
            if START < -1.0
                break;
            end
            P.LK     = -1;
            P.FA     = FMIN * 0.6;
            P.VDEPTH = FMIN * 0.3;
            break;
        end
    end

    P.KV   = 45 - JS;
    FV(44) = (P.FA + FMIN) / 2.0;
    HT(44) = P.HS + (HMIN - P.HS) * FV(44) / FMIN;
    if J == 1
        P.HS = HT(44);
    end
    FV(P.KV) = P.FA;
    HT(P.KV) = P.HA;
    FV(1)    = P.FA;
    HT(1)    = P.HA;
    P.KR     = 1;
end

function [NV, FV, HT, P] = sub_seldat(NV, FV, HT, P)
    ffit = 0.411;
    gfit = 40.1;

    while true
        P.FCC = 0.0;
        FSX   = 0.0;
        FRX   = 0.0;
        P.MF  = P.KV;
        FS    = FV(P.KV);
        F1    = 0.0;
        [P.FH, P] = fn_gind(0.0, HT(P.KR), P);
        P.NF  = 0;

        inc_nf = true;
        goto_label = 0;

        while true
            if inc_nf
                P.NF = P.NF + 1;
            end
            inc_nf = true;

            P.MF = P.MF + 1;
            FM   = FV(P.MF);
            FN   = FV(P.MF + 1);
            HV   = HT(P.MF);

            if FM <= FS
                FRX = sqrt(max(0.0, FM * (FM + P.FH)));
                if P.MF == P.KV + 1
                    FSX = FRX;
                end
                if FM < 0.0 && FRX >= FSX && P.NF == 1
                    inc_nf = false;
                    continue;
                end
                NV = -P.MF;
                return;
            end

            if F1 == 0.0
                F1 = FM;
            end
            if HV < 0.0 || FN < 0.0
                goto_label = 40; % Cusp / End
                break;
            end
            % If virtual height <= 50.0 (like 0.0 or 0.1), it's a peak or critical frequency marker
            if abs(HT(P.MF + 1)) <= 50.0
            % % % if FV(P.MF + 1) > 0.0 && abs(HT(P.MF + 1)) <= 50.0
                goto_label = 50; % Peak / foF2 marker
                break;
            end

            FS = FM;
            if FN <= FM
                NV = -P.MF;
                return;
            end
            if (P.NF + 1 < NV) && (P.MF - P.KV < P.MAXB - 8)
                continue;
            end

            GRAD = (HT(P.MF + 1) - HV) / (FN - FM);
            if (P.NF + 1 == NV) && (P.NF <= 2 || P.KR > 1 || GRAD < 100.0)
                continue;
            end

            if P.MOD > 10 || P.MOD < 4
                goto_label = 70;
                break;
            end
            if HT(P.MF + 1) - HV > (FN - FM) * gfit
                goto_label = 70;
                break;
            end
            if FRX > FSX && FM > FRX
                goto_label = 70;
                break;
            end
            if (FM - F1 + 0.04 * (P.NF - NV) < ffit) || (FM < FSX)
                continue;
            end
            goto_label = 70;
            break;
        end

        if goto_label == 40
            P.FCC    = min(FN, -0.1);
            HT(P.MF) = abs(HV);
        elseif goto_label == 50
            P.FCC = max(FN, 0.1);
        end

        if P.NF < 1
            NV = -P.MF;
            return;
        end
        MX  = P.MF - P.NF;
        KV1 = P.KV;
        redo_all = false;

        while true
            P.NX = MX - P.KV;
            if P.NX == 0
                break;
            end
            F = FV(MX);
            delete_xray = false;
            if sqrt(max(0.0, (F + P.FH) * F)) > FM + 0.1
                delete_xray = true;
            elseif P.NX == 1
                break;
            elseif HT(MX) - HT(MX - 1) < gfit * (FV(MX - 1) - F)
                break;
            else
                delete_xray = true;
            end

            if delete_xray
                for J_idx = MX : -1 : P.KV
                    FV(J_idx) = FV(J_idx - 1);
                    HT(J_idx) = HT(J_idx - 1);
                end
                P.KV = P.KV + 1;
                if P.KV > KV1 + NV
                    redo_all = true;
                    break;
                end
            end
        end

        if ~redo_all
            break;
        end
    end

    if P.NX == 0 && P.KR == 1
        P.LK = 1;
    end
end

function [FV, HT, LOOP, P] = sub_staval(FV, HT, DIP, VALLEY, LOOP, P)
    VBASE  = 0.6;
    VDEEP  = 0.008;
    VCONST = 20.0;
    VAL1   = 0.1001;
    DVAL1  = 6.0;
    VPEAK  = 1.4;
    WVX    = 1.0;
    HXERR  = 2.0;
    sq     = @(x) sqrt(max(0.0, (1.0 - x) * (1.0 + x)));

    NFB  = LOOP;
    LOOP = abs(LOOP);

    if LOOP <= 1
        if LOOP == 1
            LOOP = 4;
        end
        if LOOP ~= 4
            P.XWAT  = WVX;
            P.PARHT = 0.0;
            P.HVAL  = HT(P.KV);
            if P.HVAL == 0.0, P.HVAL = VALLEY; end
            if P.HVAL == 0.0, P.HVAL = 1.0;    end
            if P.HVAL >= 10.0, P.HVAL = 0.0;   end
            if P.HVAL == 0.0
                return;
            end

            P.staval_HDEC  = (fix(P.HVAL) - P.HVAL) * 2.0;
            P.staval_DEVL  = 1.0e6;
            P.staval_DEVLL = 1.0e7;
            P.staval_DVAL  = DVAL1;
            P.HMAX = HT(P.KR);
            SHA    = P.HMAX * 0.25 - 20.0;
            P.HS   = P.HMAX + SHA;
            P.SH   = P.SH * VPEAK;

            P.VWIDTH = (SHA + 7.0) * abs(P.HVAL);
            if P.HVAL < -2.0
                P.VWIDTH = fix(-P.HVAL) * 2.0;
            end
        end

        P.staval_VAL = (P.VWIDTH^2) * VDEEP / (VCONST + P.VWIDTH);
        if P.HMAX > 140.0
            P.staval_VAL = 0.5 * P.staval_VAL;
        end
        if P.staval_HDEC > 0.0
            P.staval_VAL = P.staval_HDEC;
        end
        if P.HVAL == -1.0 && P.NX > 0
            P.staval_VAL = VAL1;
        end
        if fix(P.HVAL) == -1
            P.HVAL = -1.0;
        end

        P.VDEPTH = P.staval_VAL;
        if P.staval_HDEC <= 0.0 || P.staval_VAL > 0.8 * P.FA
            P.VDEPTH = P.staval_VAL * P.FA / (P.staval_VAL + P.FA);
        end
        P.PARHT = 2.0 * P.SH * sq(1.0 - P.VDEPTH / P.FA);
        P.HA    = P.HMAX + P.PARHT;
        if P.NC == 0
            P.staval_FHHT = P.HA + 20.0;
        end
        return;
    end

    DEVN = P.Q(20);
    FNL  = 0.0;
    DHL  = P.Q(P.JM);

    while true
        if P.NX <= 0 || (DEVN == 0.0 && P.HVAL == -1.0)
            P.staval_DVAL = -1.0;
        end
        QM = P.Q(P.JM);
        HR = P.HA + QM;
        HN = HR;
        FN = P.FA;
        MC = P.NC;
        MV = P.NF + P.NX;
        MQ = P.MT + min(P.LK, 0);

        jump_350 = false;
        for I = 1 : MV
            HL = HN;
            FL = FN;
            FN = FV(P.KV + I);
            if FN < 0.0
                FN = sqrt(max(0.0, (FN + P.FH) * FN));
            end
            DELTF = FN - P.FA;
            HN    = HR + fn_sumval(MQ, P.Q, DELTF, 1);

            if ~(P.NC + MC >= 25 || DIP < 0.0)
                if (HN - HL) / (FN - FL) <= 2.0
                    MC = MC + 3;
                    if P.NX > 0 && P.XWAT == WVX && P.NC > 1
                        P.XWAT = WVX / 2.0;
                        LOOP = 4;
                        return;
                    end
                    qmm = QM - max(5.0, abs(QM) / 4.0) * max(1, 3 - P.KR);
                    if FN ~= FNL || HN - HL > DHL
                        [~, P.B, P.Q, DEVN, P] = sub_solve(-900, -P.JM, P.B, P.Q, qmm, DEVN, P.lbug, P);
                        FNL = FN;
                        DHL = HN - HL;
                        jump_350 = true;
                        break;
                    end
                    MC = 30;
                end
            end
            if P.KR + I < P.KV
                HT(P.KR + I) = HN;
            end
        end
        if ~jump_350
            break;
        end
    end

    P.KRM = min(P.KR + MV, P.KV - 1);
    if P.NC <= 2
        P.XWAT = WVX;
    end
    KHX = P.KR + 1 + fix(P.NX / 3);
    DHX = HT(KHX) - P.staval_FHHT;
    P.staval_FHHT = HT(KHX);
    if P.NC == 1 || abs(DHX) > HXERR
        LOOP = 3;
    end
    if P.NX <= 0 || NFB < 0 || P.NC >= 20
        LOOP = 2;
    end

    if P.KR <= 1
        SLAB = P.Q(P.MT);
        if P.LK == 0, SLAB = 0.0; end
        if LOOP == 3
            return;
        end
        KD = 1 - P.LK;
    else
        while true
            P.VWIDTH = QM + P.PARHT;
            if P.staval_HDEC > 0.0
                P.staval_DVAL = -P.staval_HDEC;
            end
            if LOOP == 3
                return;
            end

            KD   = 4;
            LOOP = 4;
            VBOT = QM * VBASE;
            SLAB = QM - VBOT;

            if P.staval_DVAL < 0.0 || P.NC > 25
                break;
            end

            if P.HVAL == -1.0
                goto_680 = false;
                if P.staval_DVAL == DVAL1
                    if P.staval_VAL == VAL1
                        P.staval_DEVL = DEVN;
                        goto_680 = true;
                    else
                        P.staval_DVAL = 1.0 + 0.5 * cos(0.015 * P.ADIP);
                        if DEVN < P.staval_DEVL
                            P.staval_DEVL = DEVN;
                            goto_680 = true;
                        else
                            P.staval_VAL = VAL1;
                            goto_680 = true;
                        end
                    end
                end
                if ~goto_680
                    if DEVN > P.staval_DEVL * 0.97 - 0.003 && P.staval_DEVLL < 1.0e6
                        DMIN = (P.staval_DEVLL - DEVN) / abs(P.staval_DEVLL + DEVN - 2.0 * P.staval_DEVL) * 0.5 - 1.0;
                        P.staval_DVAL = -(P.staval_DVAL ^ min(DMIN, 0.5));
                    elseif DEVN < P.staval_DEVL
                        P.staval_DEVLL = P.staval_DEVL;
                        P.staval_DEVL  = DEVN;
                    else
                        P.staval_DVAL  = 1.0 / P.staval_DVAL;
                        P.staval_VAL   = P.staval_VAL * P.staval_DVAL;
                        P.staval_DEVLL = DEVN;
                    end
                end
                P.staval_VAL = P.staval_VAL * abs(P.staval_DVAL);
                P.VDEPTH = P.staval_VAL;
                if P.staval_HDEC <= 0.0 || P.staval_VAL > 0.8 * P.FA
                    P.VDEPTH = P.staval_VAL * P.FA / (P.staval_VAL + P.FA);
                end
                P.PARHT = 2.0 * P.SH * sq(1.0 - P.VDEPTH / P.FA);
                P.HA    = P.HMAX + P.PARHT;
                return;
            end

            if DEVN > P.staval_DEVL / 0.9 && P.NC < 4
                SHA = (HT(P.KR) * 0.25 - 20.0);
                P.VWIDTH = (SHA + 7.0) * abs(P.HVAL);
                if P.HVAL < -2.0, P.VWIDTH = fix(-P.HVAL) * 2.0; end
                [FV, HT, LOOP, P] = staval_goto40(FV, HT, LOOP, P, VDEEP, VCONST, VAL1, sq);
                return;
            end
            if P.staval_DEVL >= 1.0e6
                P.staval_DEVL = DEVN;
                [FV, HT, LOOP, P] = staval_goto40(FV, HT, LOOP, P, VDEEP, VCONST, VAL1, sq);
                return;
            end
            P.staval_DVAL = -1.0;
            if P.lbug == 0
                continue;
            end
            break;
        end
    end

    LOOP = 2;
    P.KR = P.KR + KD;
    P.KV = P.KV + abs(P.NX);
    if KD == 0
        return;
    end
    if KD ~= 1
        FBOT         = P.FA - P.VDEPTH;
        HT(P.KR - 2) = P.HA;
        FV(P.KR - 2) = FBOT;
        HT(P.KR - 1) = P.HA + QM * VBASE;
        FV(P.KR - 1) = FV(P.KR - 2);
        if KD >= 4
            HT(P.KR - 3) = P.HA - 0.5 * P.PARHT;
            FV(P.KR - 3) = 0.5 * sqrt(3.0 * P.FA^2 + FBOT^2);
            FV(P.KV)     = P.FA;
        end
    end
    P.HA = P.HA + QM;
    if KD <= 2
        P.KR = KD;
    end
    HT(P.KR) = P.HA;
    FV(P.KR) = P.FA;
    if P.KR <= 3
        HT(1)        = P.HA - SLAB;
        FV(P.KV - 1) = P.FA;
        F1           = FV(P.KV + 1);
        if P.LK == 0
            FV(P.KV - 1) = (P.FA + F1) * 0.5;
        end
        FV(P.KV) = (FV(P.KV - 1) + F1) * 0.5;
        P.KV     = P.KV - 2 - P.LK;
        VBOT     = 0.0;
    end
    if P.KR > 1
        P.tcont = P.tcont + (FV(P.KR - 1)^2) * (VBOT + 0.5 * SLAB) + (P.FA^2) * 0.5 * SLAB ...
                  + P.PARHT * (P.FA^2 - P.VDEPTH * (P.FA + FV(P.KR - 1)) / 3.0);
    end
end

function [FV, HT, LOOP, P] = staval_goto40(FV, HT, LOOP, P, VDEEP, VCONST, VAL1, sq)
    P.staval_VAL = (P.VWIDTH^2) * VDEEP / (VCONST + P.VWIDTH);
    if P.HMAX > 140.0
        P.staval_VAL = 0.5 * P.staval_VAL;
    end
    if P.staval_HDEC > 0.0
        P.staval_VAL = P.staval_HDEC;
    end
    if P.HVAL == -1.0 && P.NX > 0
        P.staval_VAL = VAL1;
    end
    if fix(P.HVAL) == -1
        P.HVAL = -1.0;
    end
    P.VDEPTH = P.staval_VAL;
    if P.staval_HDEC <= 0.0 || P.staval_VAL > 0.8 * P.FA
        P.VDEPTH = P.staval_VAL * P.FA / (P.staval_VAL + P.FA);
    end
    P.PARHT = 2.0 * P.SH * sq(1.0 - P.VDEPTH / P.FA);
    P.HA    = P.HMAX + P.PARHT;
end

function [FV, HT, P] = sub_coefic(MV, FV, HT, P)
    TR = [0.046910077, 0.23076534,  0.50,       0.76923466, 0.95308992, ...
          0.009219683, 0.047941372, 0.11504866, 0.20634102, 0.31608425, 0.43738330, ...
          0.56261670,  0.68391575,  0.79365898, 0.88495134, 0.95205863, 0.99078032];
    W  = [0.11846344,  0.23931434,  0.28444444, 0.23931434, 0.11846344, ...
          0.02358767,  0.05346966,  0.08003917, 0.10158371, 0.11674627, 0.12457352, ...
          0.12457352,  0.11674627,  0.10158371, 0.08003917, 0.05346966, 0.02358767];
    VB  = 0.6;
    GTC = 180.0;
    sq  = @(x) sqrt(max(0.0, (1.0 - x) * (1.0 + x)));

    GAUSS = zeros(17, 1);
    FNR   = zeros(17, 1);

    F1  = FV(P.KV + 1);
    NFF = abs(MV);
    KM  = P.KV + NFF;
    FW  = FV(KM + 1);
    if FW < 1.0
        FW = FV(KM) * 2.0 - FV(KM - 1);
    end
    I_tmp = P.KV + min(NFF, max(P.MOD - 15, 2) + P.NR);
    DW    = FW - FV(I_tmp);
    DA    = FV(P.KV + P.NR - P.NL) - P.FA;

    HR = P.HA + 10.0 * min(1, P.KR - 1);
    if P.KRM > P.KR
        HR = HT(P.KR + 1);
    end
    if P.KRM == P.KR
        P.coefic_FTC = P.FA * 1.2;
    end
    if P.HVAL ~= 0.0
        P.HS = P.HMAX + P.VWIDTH / 3.0;
    end

    if MV >= 0
        if ~(P.LK >= 0 || P.KRM == P.KR)
            DELTF = 0.0;
            GRAD2 = P.Q(1) - GTC;
            if GRAD2 >= 0.0
                while true
                    grad1 = GRAD2;
                    DELTF = DELTF + 0.1 * P.FA;
                    GRAD2 = fn_sumval(P.MT - 1, P.Q, DELTF, 2) - GTC;
                    if ~(GRAD2 > 0.0 && DELTF < P.FA * 0.45)
                        break;
                    end
                end
                DELTF = DELTF + 0.1 * P.FA * min(GRAD2, 0.0) / (grad1 - GRAD2);
            end
            P.coefic_FTC = (P.coefic_FTC + P.FA + DELTF) * 0.5;
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % % P.B(1 : P.MAXB, 1 : 19) = 0.0;
        P.B(:) = 0.0;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end

    I = 1 - P.NL;
    if I == 0 && P.MOD ~= 12
        I = -1;
    end
    if MV < 0
        I = 1;
    end

    while true
        IREAL = NFF + P.NL + max(I, 0);
        KVI   = P.KV + I;
        KRI   = P.KR + I;

        F   = FV(KVI);
        HV  = HT(KVI);
        FR2 = F * F;
        if KRI <= P.KRM
            HR = HT(KRI) * 0.8 + HT(P.KR + 1) * 0.2;
        end
        HFH = HR;
        if F1 < 0.0
            HFH = P.HS;
        end
        [P.FH, P] = fn_gind(0.0, HFH, P);
        if F < 0.0
            FR2 = F * (F + P.FH);
        end
        FR = sqrt(max(0.0, FR2));

        WREAL = 10.0;
        if KVI < P.KV
            WREAL = 3.0;
        end

        WVIRT = 1.0;
        DEPAR = 0.0;
        DELIN = 0.0;
        GINDV = 0.0;
        ira   = 1;
        irb   = 5;

        if I > 0
            if FR <= FV(P.KR) || FR <= P.FC
                P.JM = -P.JM;
            end
            if P.PARHT > 2.0 * P.SH || NFF + P.NR > P.MAXB
                P.JM = -P.JM;
            end
            if P.JM <= 0
                return;
            end

            if MV >= 0
                WVIRT = 1.0;
                if F < 0.0 || FW <= FR
                    WVIRT = P.XWAT;
                elseif P.NR > P.NL && P.FCC == 0.0
                    WVIRT = sqrt(max(0.0, min((FR - P.FA) / DA, (FW - FR) / DW)));
                end
                P.B(I, 18) = F;
                P.B(I, 19) = WVIRT;

                FVL = FV(KVI - 1);
                if ~(P.NX > 0 || F < 0.0 || FVL < 0.0)
                    DELTF = (FV(KVI + 1) - FVL) / 2.0;
                    if DELTF < 0.0
                        DELTF = F - FVL;
                    end
                    WVIRT = WVIRT * sqrt(8.0 * abs(DELTF) / sqrt(F));
                end
            end

            TB = sq(P.FA / FR);
            TA = 0.0;
            if MV < 0
                FP = FV(P.KR);
                if FP == P.FC
                    FP = FV(P.KR - 2);
                end
                TA   = sq(FP / FR);
                inum = 5;
                if P.ADIP > 73.0 && TA < 0.3
                    inum = 12;
                end
            else
                P.coefic_FTC = min(P.coefic_FTC, P.FA * 0.2 + FR * 0.8);
                TC   = 0.39 - 0.05 / cos(0.016 * P.ADIP);
                inum = 5;
                if P.ADIP >= 60.0 || P.MODE >= 8
                    inum = 12;
                end
                if P.ADIP >= 80.0 && TB > 1.2 * TC
                    inum = 17;
                end
                if F1 < 0.0
                    inum = 17;
                    TC   = sq(P.coefic_FTC / FR);
                end
            end

            ira = 1;
            if inum == 12
                ira = 6;
            end
            irb = ira + inum - 1;
            if inum == 17
                TA = TC;
            end
            TD = TB - TA;

            DEPAR = 0.0;
            DELIN = 0.0;
            if ~(P.LK >= 0 && P.PARHT == 0.0)
                DZ = 0.0;
                if P.SH ~= 0.0
                    DZ = 0.5 * P.PARHT / P.SH;
                end
                for IR = 6 : 17
                    if P.LK >= 0
                        TP = sq(P.FC / FR * sq(TR(IR) * DZ));
                        [g_val, P] = fn_gind(F, TP, P);
                        DEPAR = DEPAR + g_val * W(IR);
                    end
                    [GINDV, P] = fn_gind(F, sq((P.FA - TR(IR) * P.VDEPTH) / FR), P);
                    DELIN = DELIN + GINDV * W(IR);
                end
                if P.PARHT > 0.0
                    [P.FH, P] = fn_gind(0.0, (P.HMAX + P.VWIDTH) * 0.8 + HR * 0.2, P);
                end
            end

            for IR = ira : irb
                if inum == 17 && IR == 6
                    TD = TA;
                    TA = 0.0;
                    [P.FH, P] = fn_gind(0.0, HR, P);
                    if F <= 0.0
                        FR2 = F * (F + P.FH);
                        FR  = sqrt(max(0.0, FR2));
                        TD  = sq(P.coefic_FTC / FR);
                    end
                end
                T  = TR(IR) * TD + TA;
                FN = sq(T) * FR;
                [g_val, P] = fn_gind(F, T, P);
                GAUSS(IR)  = g_val * T * W(IR) / FN * TD * FR2;
                FNR(IR)    = FN - P.FA;
            end
        end

        for J = 1 : P.JM
            RH    = (FR - P.FA) ^ J;
            DPEAK = 0.0;
            SUM   = 0.0;
            if KVI == P.KV && J == 1
                RH = 1.0;
            end
            if I > 0
                if J == P.JM
                    DPEAK = DEPAR * P.PARHT;
                end
                if J >= P.MT && (J ~= P.MT || P.LK < 0)
                    RH = J - P.MT;
                    if J == P.MT
                        SUM = DELIN;
                    end
                    if P.LK > 0
                        SUM = GINDV * VB + DELIN * (1.0 - VB);
                    end
                else
                    for IR = ira : irb
                        A         = GAUSS(IR);
                        GAUSS(IR) = A * FNR(IR);
                        SUM       = SUM + A;
                    end
                    SUM = J * SUM;
                end
                P.B(I, J) = (SUM + RH) * WVIRT;
                if MV < 0
                    s_sum = abs(SUM) * sign_fortran(1.0, HV);
                    s_dpk = abs(DPEAK) * sign_fortran(1.0, HV);
                    HT(KVI) = HT(KVI) - P.Q(J) * s_sum - s_dpk;
                end
            end
            if IREAL <= NFF + P.NR
                P.B(IREAL, J) = RH * WREAL;
            end
        end

        if MV >= 0
            if I > 0
                P.B(I, P.JM + 1) = (HV - P.HA - DPEAK) * WVIRT;
            end
            if IREAL <= NFF + P.NR
                REAL_val = HT(KRI) - P.HA;
                if P.MOD == 12
                    REAL_val = P.Q(1) + 2.0 * P.Q(2) * (P.FA - FV(P.KR - 1));
                end
                P.B(IREAL, P.JM + 1) = REAL_val * WREAL;
            end
        end

        I = max(I, 0) + 1;
        if I > NFF
            break;
        end
    end
end

function [BB, Q, LBUG, P] = sub_adjust(HA, FA, FM, FC, LK, JM, MT, BB, Q, LBUG, P)
    lflag = fix((LBUG + 50) / 100);
    LBUG  = LBUG - lflag * 100;
    ladj  = 0;

    DEVN = Q(20);
    MQ   = MT;
    if LK < 0
        MQ = MT - 1;
    end
    if lflag > 3 || JM < 4
        return;
    end

    QMIN = 2.0;
    if lflag <= 1
        if LK <= 1
            QMAX = 80.0;
            if LK == -1, QMAX = 160.0; end
            if Q(1) > QMAX
                QMIN = 2.0 * QMAX * Q(1) / (QMAX + Q(1));
            end
        else
            if JM > MT
                QMIN = HA / 4.0 - 20.0;
            end
        end

        if Q(1) < QMIN || QMIN >= 85.0
            [~, BB, Q, DEVN, P] = sub_solve(-900, -1, BB, Q, QMIN, DEVN, LBUG, P);
            ladj = ladj + 1;
        end
        if JM > MT && LK > 0 && Q(2) >= -1.5
            [~, BB, Q, DEVN, P] = sub_solve(-900, -2, BB, Q, -1.5, DEVN, LBUG, P);
            ladj = ladj + 2;
        end
    end

    while true
        QL = Q(MQ);
        if MQ < 5 || abs(QL) < 150.0 || FC > 0.0 || LK <= 0
            break;
        end
        fix_it = false;
        if (QL / Q(MQ - 2) > 2.0) && (QL / Q(MQ - 1) < -1.0)
            fix_it = true;
        elseif ~(abs(QL) < 999.0 && abs(Q(MQ - 1)) < 999.0)
            fix_it = true;
        end
        if fix_it
            [~, BB, Q, DEVN, P] = sub_solve(900, -MQ, BB, Q, 0.0, DEVN, LBUG, P);
            MQ = MQ - 1;
        else
            break;
        end
    end

    if JM ~= MT
        if LK <= 0
            QM  = Q(MT);
            QMT = 0.1;
            if QM < 0.0
                [~, BB, Q, DEVN, P] = sub_solve(-900, -MT, BB, Q, QMT, DEVN, LBUG, P);
                if DEVN > Q(19) * 1.25
                    [~, BB, Q, DEVN, P] = sub_solve(0, -MT, BB, Q, QMT, DEVN, LBUG, P);
                end
            end
            OFST = -0.1;
            do_450 = false;
            if Q(JM) > 0.0
                do_450 = true;
            elseif ~(LK >= 0 || HA + Q(JM) > 60.0)
                OFST   = 60.0 - HA;
                do_450 = true;
            end
            if do_450
                [~, BB, Q, DEVN, P] = sub_solve(-900, -JM, BB, Q, OFST, DEVN, LBUG, P);
            end
        else
            if Q(JM) < 0.0
                OFST = 0.1;
                [~, BB, Q, DEVN, P] = sub_solve(-900, -JM, BB, Q, OFST, DEVN, LBUG, P);
            end
        end
    end

    if FC <= 0.0 || MQ < 4
        return;
    end
    hfm = HA + fn_sumval(MQ, Q, FM - FA, 1);
    shm = max(0.27 * hfm - 21.0, 5.0);
    d   = FC - FM;
    if d < 0.03
        d = 0.1 * sqrt(FM) + 0.03 * FM;
    end
    curve = 0.28 * shm / (d * sqrt(FM * d));
    if fn_sumval(MQ, Q, FM - FA, 3) > curve
        return;
    end
    devn_df = FM - FA;
    [~, BB, Q, DEVN, P] = sub_solve(100, -300, BB, Q, curve, devn_df, LBUG, P);
    if Q(1) > QMIN || mod(ladj, 2) == 1
        return;
    end
    [~, BB, Q, ~, P] = sub_solve(-900, -1, BB, Q, QMIN, DEVN, LBUG, P);
end

function [FV, HT, P] = sub_reduce(FV, HT, P)
    K    = P.MF;
    FRED = FV(P.MF) + 0.04 * double(P.MODE);
    while true
        K = K + 1;
        if ~(abs(HT(K)) > 40.0 && FV(K) <= FRED)
            break;
        end
    end

    KV1 = P.KV + 1;
    KVM = min(K - 1, P.KV + P.MAXB - P.NR);
    [FV, HT, P] = sub_coefic(P.KV - KVM, FV, HT, P);
    if P.JM <= 0
        return;
    end

    bad_k = 0;
    for k_idx = KV1 : KVM
        if abs(HT(k_idx)) < P.HA
            bad_k = k_idx;
            break;
        end
    end
    if bad_k > 0
        k_cur = bad_k;
        while k_cur > P.KV - 4
            FV(k_cur) = FV(k_cur - 1);
            HT(k_cur) = HT(k_cur - 1);
            k_cur     = k_cur - 1;
        end
        P.KV = KV1;
    end

    MQ   = P.MT + min(P.LK, 0);
    P.LK = max(P.LK, 1) + 1;
    FAR  = FV(P.KR);
    G2   = P.Q(1);

    for L = P.LK : P.KR
        FL   = FV(L - 1);
        FN   = FV(L);
        AVN  = (FL^2 + FN * (FL + FN)) / 3.0;
        P.HA = HT(L);
        DH   = P.HA - HT(L - 1);

        DELTF = FN - P.FA;
        G1    = G2;
        if FN ~= P.FC && FN > P.FA
            G2 = fn_sumval(MQ, P.Q, DELTF, 2);
        end
        if FN == P.FC || FN < P.FA
            AVN = AVN + FN * (FN - FL) / 3.0;
        end
        DH = DH + (G2 - G1) * (FL + FN) * ((FN - FL)^2) / (12.0 * AVN);
        [P.FH, P] = fn_gind(0.0, P.HA, P);

        K_idx = KVM;
        while true
            K_idx = K_idx + 1;
            F     = FV(K_idx);
            if F == -1.0
                break;
            end
            FR = F;
            HV = HT(K_idx);
            if HV == 0.0 && HT(K_idx + 1) == 0.0
                break;
            end
            if abs(HV) <= 40.0
                continue;
            end
            f_err = false;
            if F < 0.0 && F > -P.FH
                f_err = true;
            else
                if F < 0.0
                    FR = sqrt(max(0.0, (F + P.FH) * F));
                end
                if FR < FAR
                    f_err = true;
                end
            end
            if f_err
                FV(K_idx) = -1.0;
                break;
            end
            TAV = sqrt(max(0.0, 1.0 - AVN / (FR^2)));
            [g_val, P] = fn_gind(F, TAV, P);
            HT(K_idx)  = HV - g_val * DH * sign_fortran(1.0, HV);
        end
    end
    P.LK = P.KR;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [FV, HT, QQ, P] = sub_peak(FV, HT, QQ, P)
    PQ   = zeros(20, 1);
    P.KR = P.KR + 1;
    P.KV = P.KV + 1;
    FM   = FV(P.KRM);
    HN   = HT(P.KRM);
    HT(P.KRM) = HN;

    NK = min(fix(P.NF * 9 / (P.NF + 9)), fix(P.KR / 3)) + 2;
    if FV(P.KV - NK) < FM * 0.7
        NK = NK - 1;
    end
    if FV(P.KV - NK) < FM * 0.85 && NK > 5
        NK = NK - 1;
    end
    if P.MODE == 10 || P.MODE >= 30
        NK = NK - 1;
    end
    NK = max(1, NK);

    KA     = P.KV - 1 - NK;
    KB     = P.KRM - NK;
    P.SH   = max(0.27 * HN - 21.0, 5.0);
    P.HMAX = HN + 0.3 * P.SH;
    [P.FH, P] = fn_gind(0.0, P.HMAX, P);

    MK  = NK;
    if P.FCC > 0.1
        MK = MK + 1;
    end
    FCX = abs(FV(P.KV + 1));
    HCX = HT(P.KV + 1);
    if abs(HCX) <= 30.0 && FCX >= FM + 0.5 * P.FH
        MK           = MK + 1;
        FV(P.KV + 1) = FV(P.KV);
        FV(P.KV)     = FCX;
        HT(P.KV + 1) = HT(P.KV);
        HT(P.KV)     = HCX;
        P.KV         = P.KV + 1;
    end
    FV(P.KR) = P.FCC;
    HT(P.KR) = HT(P.KV);

    fnext = FV(P.KV + 1);
    if fnext == -1.0
        fnext = 0.0;
    end
    if fnext < 0.0
        fnext = sqrt(max(0.0, fnext * (fnext + 0.99 * P.FH)));
        i_oray = 60;
        for ii = 2 : 60
            if FV(P.KV + ii) >= 0.0
                i_oray = ii;
                break;
            end
        end
        fnext = min(fnext, FV(P.KV + i_oray));
    end

    devn = 0.0;
    qset = 0.0;
    GMAX = 0.0;
    LOOP_final = 1;

    for LOOP = 1 : 3
        LOOP_final = LOOP;
        pgrad = 1.0;
        for I = 1 : MK
            F = FV(KA + I);
            if F == FCX
                F = sqrt(max(0.0, FCX * (FCX - P.FH)));
            end
            W_wt = (2.0 ^ (14.0 * (F - FM) / F)) / 0.7;
            GRAD = 0.0;
            if F <= FM
                W_wt = W_wt * 0.7;
                MQ   = P.MT + min(P.LK, 0);
                GRAD = 4.0 / F / max(fn_sumval(MQ, P.Q, F - P.FA, 2), 3.0);
                if I == NK
                    GRAD = GRAD - GRAD * 0.2 * ((1.0 - double(P.MT) / double(P.NF))^3);
                end
            end
            T          = P.SH * GRAD;
            pgrad      = pgrad * 20.0 * max(GRAD, 0.002);
            P.B(I, 1)  = W_wt;
            P.B(I, 5)  = GRAD;
            P.B(I, 6)  = (log(1.0 + T) - T) * 0.25;
            P.B(I, 2)  = P.B(I, 6) * W_wt;
            P.B(I, 3)  = log(F) * W_wt;
        end

        w_cond = 0.1 * sqrt(pgrad) + 0.02;
        P.B(MK + 1, 1) = 0.0;
        P.B(MK + 1, 2) = w_cond;
        P.B(MK + 1, 3) = w_cond;

        [~, P.B, PQ, devn, P] = sub_solve(MK + 1, 2, P.B, PQ, qset, devn, P.lbug, P);

        GMAX  = P.B(NK, 5);
        erfac = 400.0 / (1.0 + MK - NK) / (NK - 0.8) * devn;
        qfac  = 0.1 / GMAX - 0.1 / P.B(fix((NK + 1) / 2), 5);
        if qfac < erfac

        % % % fprintf('  [AVSH TRIGGERED] Before avsh: PQ(2) = %.4f\n', PQ(2));            

            avsh = max(PQ(2), 0.0) * 0.5 + 0.5;
            if PQ(2) > 1.0
                avsh = PQ(2) / avsh;
            end

            [~, P.B, PQ, devn, P] = sub_solve(10, -2, P.B, PQ, avsh, devn, P.lbug, P);
   
        % % % fprintf('  [AVSH TRIGGERED] After avsh:  PQ(2) = %.4f (avsh = %.4f)\n', PQ(2), avsh);        

        end

        P.FC = exp(PQ(1));
        if MK == NK && P.FC > 1.5 * FM
            [~, P.B, PQ, devn, P] = sub_solve(400, -1, P.B, PQ, log(1.5 * FM), devn, P.lbug, P);
        end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % % Physical limits for ScaleHt in the F-region (in km)
        % min_allowed_SH = 30.0;
        % max_allowed_SH = 100.0;        
        
        P.SH    = P.SH * sqrt(abs(PQ(2)));
        
        % % No multipliers, no adaptive damping — pure original algorithm value of P.SH
        % % Just apply hard physical clamping to prevent mathematical collapse
        % P.SH = max(min(P.SH, max_allowed_SH), min_allowed_SH);
        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % % If PQ(2) is positive, update ScaleHt standardly following Titheridge's algorithm.
        % % If PQ(2) is negative (indicating mathematical instability on real-world data),
        % % we prevent the scale height from collapsing and apply gentle damping instead.
        % if PQ(2) > 0.0
        %     P.SH = P.SH * sqrt(PQ(2));
        % else
        %     % Prevent catastrophic scale height collapse by gently holding/damping it
        %     P.SH = P.SH * 0.95; 
        % end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % % Physical limits for ScaleHt in the F-region based on polar ionosphere physics (in km)
        % min_allowed_SH = 25.0;
        % max_allowed_SH = 90.0;
        % 
        % if PQ(2) > 0.0
        %     % Apply gentle damping (alpha = 0.4) to avoid sharp hmF2 jumps
        %     alpha = 0.4; 
        %     correction_factor = 1.0 + alpha * (sqrt(PQ(2)) - 1.0);
        %     P.SH = P.SH * correction_factor;
        % else
        %     % Smooth damping instead of a sharp drop when mathematical instability occurs
        %     P.SH = P.SH * 0.99; 
        % end
        % 
        % % Hard physical clamping within realistic polar ionosphere bounds
        % P.SH = max(min(P.SH, max_allowed_SH), min_allowed_SH);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % % Physical limits for ScaleHt in the F-region (in km)
        % min_allowed_SH = 25.0;
        % max_allowed_SH = 90.0;
        % 
        % if PQ(2) > 0.0
        %     raw_factor = sqrt(PQ(2));
        % 
        %     % Option 1: Soft-clipping (tanh-based compression) to prevent extreme jumps 
        %     % while keeping high responsiveness for moderate values
        %     controlled_factor = 1.0 + 0.6 * tanh(raw_factor - 1.0);
        % 
        %     % Option 2: Tapering the correction near the peak to protect hmF2 accuracy
        %     % (assuming K is current step index and K_total is total steps, or using frequency proximity)
        %     % Let's apply a smooth limiter directly to the multiplier:
        %     correction_factor = max(0.8, min(1.3, controlled_factor));
        % 
        %     P.SH = P.SH * correction_factor;
        % else
        %     % Gentle smoothing during mathematical instability
        %     P.SH = P.SH * 0.98; 
        % end
        % 
        % % Hard physical clamping within realistic polar ionosphere bounds
        % P.SH = max(min(P.SH, max_allowed_SH), min_allowed_SH);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% % fprintf('--- LOOP %d ---\n', LOOP);
% % fprintf('  Initial HN = %.1f km, Starting SH = %.2f km\n', HN, P.SH / sqrt(abs(PQ(2)))); % если до умножения
% % fprintf('  PQ(2) factor = %.4f\n', PQ(2));
% % fprintf('  Updated SH   = %.2f km\n', P.SH);
% % fprintf('  qfac = %.4f, erfac = %.4f\n', qfac, erfac);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        P.PARHT = P.SH * min(log(1.0 + P.SH * GMAX), 1.8);
        P.HMAX  = HN + P.PARHT;
        [P.FH, P] = fn_gind(0.0, P.HMAX, P);

        if P.PARHT > P.SH / LOOP
            break;
        end
        if qfac < erfac * 2.0 * (LOOP^2)
            break;
        end
    end

    P.FC = exp(PQ(1));
    fcn  = 0.0;
    fcm  = fnext * 0.8 + FM * 0.2 - 0.015;
    if P.FC > fcm && fcm > FM
        fcn = fcm;
    end
    if P.FC < FM * 1.002
        fcn = FM * 1.002;
    end
    if fcn ~= 0.0
        [~, P.B, PQ, devn, P] = sub_solve(300, -1, P.B, PQ, log(fcn), devn, P.lbug, P);
    end
    P.FC  = max(exp(PQ(1)), FM * 1.002);
    SHR   = PQ(2);
    SUMHW = 0.0;
    SUMW  = 0.0;
    fw    = FV(max(KB, 1));
    HMX   = 0.0;
    hlx   = 0.0;
    ZM    = 0.0;

    for I = 1 : NK
        W_wt = (FV(KB + I) - fw)^2;
        % Guard against r >= 0 by capping ratio strictly below 1.0 to avoid NaN in sqrt
        ratio_fc = min(0.9999, FV(KB + I) / P.FC);
        r    = min(-1e-7, 4.0 * log(ratio_fc));
        zf   = sqrt(-2.0 * r);
        for ii = 1 : 3
            rf = 1.0 + zf - exp(zf);
            gf = rf - zf;
            zf = zf + (r - rf) / gf;
        end
        ZM    = zf;
        hlx   = HMX;
        HMX   = HT(KB + I) + P.SH * ZM;
        SUMHW = SUMHW + HMX * W_wt;
        SUMW  = SUMW + W_wt;
    end
    P.HMAX = SUMHW / max(1e-9, SUMW);

    HADJ = 0.0;
    fadj = 0.0;
    if P.NF >= 3
        HADJ          = P.HMAX - HMX;
        HT(P.KRM)     = HN + HADJ * 0.80;
        HT(P.KRM - 1) = HT(P.KRM - 1) + (P.HMAX - hlx) * 0.40;
        fchap         = P.FC * exp(0.25 * (ZM - P.SH * GMAX));
        fadj          = fchap - FM;
    end
    P.PARHT    = P.HMAX - HT(P.KRM);
    HT(P.KR)   = P.HMAX - 0.5 * P.PARHT;
    z_half     = 0.5 * P.PARHT / P.SH;
    FV(P.KR)   = P.FC * exp(0.25 * (1.0 + z_half - exp(z_half)));
    P.KR       = P.KR + 1;
    FV(P.KR)   = P.FC;
    HT(P.KR)   = P.HMAX;
    DEVN       = devn * 2.0 / (1.0 + MK - NK);

    if fnext ~= 0.0
        P.FC = min(P.FC, fnext - 0.03);
        dfc  = FV(P.KR) - P.FC;
        FM   = FM - dfc;
        DEVN = min(DEVN, 0.5 * (fnext - FM) / P.FC);
        if dfc > 0.01
            df = dfc / (FV(P.KR)^3);
            for k_idx = 1 : P.KR
                FV(k_idx) = FV(k_idx) - df * (FV(k_idx)^3);
            end
            P.FA = P.FA - df * (P.FA^3);
        end
    end

    devf    = P.FC * DEVN + abs(fadj);
    bavge   = -P.B(2, 6) - P.B(NK, 6);
    devs    = P.SH / SHR * DEVN / bavge;
    devh    = DEVN * P.PARHT / bavge + devs * P.SH * GMAX + abs(HADJ);
    P.tcont = P.tcont + P.PARHT * (P.FC^2 + 0.5 * FM^2) / 1.5;
    SSH     = P.SH;
    if LOOP_final == 1
        SSH = -P.SH;
    end
    if P.lbug >= -9
        fprintf('PEAK%7.3f (%5.3f) MHz,  Height%6.1f (%4.1f) km.    ScaleHt%5.1f (%4.1f) km  SlabT%6.1f km\n', ...
            P.FC, devf, P.HMAX, devh, SSH, devs, P.tcont / (P.FC^2));
    end
    FV(P.KR + 4) = devf;
    HT(P.KR + 4) = devh;
    FV(P.KV)     = P.FC;

    if QQ(1) > 1.0
        numq = fix(QQ(1));
        for j_idx = (numq + 1) : (numq + 4)
            if j_idx <= numel(QQ) && QQ(j_idx) == -1.0
                return;
            end
        end
        wf = 0.1 + 0.9 / P.NF;
        fp = FV(P.KRM) * wf + FV(P.KRM - 1) * (1.0 - wf);
        fp = min(fp, 0.98 * P.FC);
        QQ(numq + 1) = max(fp, 0.90 * FM);
        QQ(numq + 2) = P.FC;
        QQ(numq + 3) = P.HMAX;
        QQ(numq + 4) = SSH;
        QQ(1)        = numq + 4;
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% % % function [FV, HT, QQ, P] = sub_peak(FV, HT, QQ, P)
% % %     PQ   = zeros(20, 1);
% % %     P.KR = P.KR + 1;
% % %     P.KV = P.KV + 1;
% % %     FM   = FV(P.KRM);
% % %     HN   = HT(P.KRM);
% % %     HT(P.KRM) = HN;
% % % 
% % %     NK = min(fix(P.NF * 9 / (P.NF + 9)), fix(P.KR / 3)) + 2;
% % %     if FV(P.KV - NK) < FM * 0.7
% % %         NK = NK - 1;
% % %     end
% % %     if FV(P.KV - NK) < FM * 0.85 && NK > 5
% % %         NK = NK - 1;
% % %     end
% % %     if P.MODE == 10 || P.MODE >= 30
% % %         NK = NK - 1;
% % %     end
% % %     NK = max(1, NK);
% % % 
% % %     KA     = P.KV - 1 - NK;
% % %     KB     = P.KRM - NK;
% % %     P.SH   = max(0.27 * HN - 21.0, 5.0);
% % %     P.HMAX = HN + 0.3 * P.SH;
% % %     [P.FH, P] = fn_gind(0.0, P.HMAX, P);
% % % 
% % %     MK  = NK;
% % %     if P.FCC > 0.1
% % %         MK = MK + 1;
% % %     end
% % %     FCX = abs(FV(P.KV + 1));
% % %     HCX = HT(P.KV + 1);
% % %     if abs(HCX) <= 30.0 && FCX >= FM + 0.5 * P.FH
% % %         MK           = MK + 1;
% % %         FV(P.KV + 1) = FV(P.KV);
% % %         FV(P.KV)     = FCX;
% % %         HT(P.KV + 1) = HT(P.KV);
% % %         HT(P.KV)     = HCX;
% % %         P.KV         = P.KV + 1;
% % %     end
% % %     FV(P.KR) = P.FCC;
% % %     HT(P.KR) = HT(P.KV);
% % % 
% % %     fnext = FV(P.KV + 1);
% % %     if fnext == -1.0
% % %         fnext = 0.0;
% % %     end
% % %     if fnext < 0.0
% % %         fnext = sqrt(max(0.0, fnext * (fnext + 0.99 * P.FH)));
% % %         i_oray = 60;
% % %         for ii = 2 : 60
% % %             if FV(P.KV + ii) >= 0.0
% % %                 i_oray = ii;
% % %                 break;
% % %             end
% % %         end
% % %         fnext = min(fnext, FV(P.KV + i_oray));
% % %     end
% % % 
% % %     devn = 0.0;
% % %     qset = 0.0;
% % %     GMAX = 0.0;
% % %     LOOP_final = 1;
% % % 
% % %     for LOOP = 1 : 3
% % %         LOOP_final = LOOP;
% % %         pgrad = 1.0;
% % %         for I = 1 : MK
% % %             F = FV(KA + I);
% % %             if F == FCX
% % %                 F = sqrt(max(0.0, FCX * (FCX - P.FH)));
% % %             end
% % %             W_wt = (2.0 ^ (14.0 * (F - FM) / F)) / 0.7;
% % %             GRAD = 0.0;
% % %             if F <= FM
% % %                 W_wt = W_wt * 0.7;
% % %                 MQ   = P.MT + min(P.LK, 0);
% % %                 GRAD = 4.0 / F / max(fn_sumval(MQ, P.Q, F - P.FA, 2), 3.0);
% % %                 if I == NK
% % %                     GRAD = GRAD - GRAD * 0.2 * ((1.0 - double(P.MT) / double(P.NF))^3);
% % %                 end
% % %             end
% % %             T          = P.SH * GRAD;
% % %             pgrad      = pgrad * 20.0 * max(GRAD, 0.002);
% % %             P.B(I, 1)  = W_wt;
% % %             P.B(I, 5)  = GRAD;
% % %             P.B(I, 6)  = (log(1.0 + T) - T) * 0.25;
% % %             P.B(I, 2)  = P.B(I, 6) * W_wt;
% % %             P.B(I, 3)  = log(F) * W_wt;
% % %         end
% % % 
% % %         w_cond = 0.1 * sqrt(pgrad) + 0.02;
% % %         P.B(MK + 1, 1) = 0.0;
% % %         P.B(MK + 1, 2) = w_cond;
% % %         P.B(MK + 1, 3) = w_cond;
% % % 
% % %         % Debug print equivalent to Fortran lbug == 8
% % %         if abs(P.lbug) == 8
% % %             fprintf(' peak: nk=%3d, mk=%3d, sh=%6.1f, w=%7.3f\n', NK, MK, P.SH, w_cond);
% % %             if LOOP == 1
% % %                 fprintf('        F      H      G      W\n');
% % %                 for k_idx = 1 : MK
% % %                     fprintf('     %7.2f%7.2f%7.2f%7.3f\n', FV(KB + k_idx), HT(KB + k_idx), P.B(k_idx, 5), P.B(k_idx, 1));
% % %                 end
% % %             end
% % %         end
% % % 
% % %         [~, P.B, PQ, devn, P] = sub_solve(MK + 1, 2, P.B, PQ, qset, devn, P.lbug, P);
% % % 
% % %         GMAX  = P.B(NK, 5);
% % %         erfac = 400.0 / (1.0 + MK - NK) / (NK - 0.8) * devn;
% % %         qfac  = 0.1 / GMAX - 0.1 / P.B(fix((NK + 1) / 2), 5);
% % %         if qfac < erfac
% % %             avsh = max(PQ(2), 0.0) * 0.5 + 0.5;
% % %             if PQ(2) > 1.0
% % %                 avsh = PQ(2) / avsh;
% % %             end
% % %             [~, P.B, PQ, devn, P] = sub_solve(10, -2, P.B, PQ, avsh, devn, P.lbug, P);
% % %         end
% % % 
% % %         P.FC = exp(PQ(1));
% % %         if MK == NK && P.FC > 1.5 * FM
% % %             [~, P.B, PQ, devn, P] = sub_solve(400, -1, P.B, PQ, log(1.5 * FM), devn, P.lbug, P);
% % %         end
% % %         P.SH    = P.SH * sqrt(abs(PQ(2)));
% % %         P.PARHT = P.SH * min(log(1.0 + P.SH * GMAX), 1.8);
% % %         P.HMAX  = HN + P.PARHT;
% % %         [P.FH, P] = fn_gind(0.0, P.HMAX, P);
% % % 
% % %         if abs(P.lbug) == 8
% % %             fprintf(' qfac=%.4f, erfac=%.4f, parht=%.2f\n', qfac, erfac, P.PARHT);
% % %         end
% % % 
% % %         if P.PARHT > P.SH / LOOP
% % %             break;
% % %         end
% % %         if qfac < erfac * 2.0 * (LOOP^2)
% % %             break;
% % %         end
% % %     end
% % % 
% % %     P.FC = exp(PQ(1));
% % %     fcn  = 0.0;
% % %     fcm  = fnext * 0.8 + FM * 0.2 - 0.015;
% % %     if P.FC > fcm && fcm > FM
% % %         fcn = fcm;
% % %     end
% % %     if P.FC < FM * 1.002
% % %         fcn = FM * 1.002;
% % %     end
% % %     if fcn ~= 0.0
% % %         [~, P.B, PQ, devn, P] = sub_solve(300, -1, P.B, PQ, log(fcn), devn, P.lbug, P);
% % %     end
% % %     P.FC  = max(exp(PQ(1)), FM * 1.002);
% % %     SHR   = PQ(2);
% % %     SUMHW = 0.0;
% % %     SUMW  = 0.0;
% % %     fw    = FV(max(KB, 1));
% % %     HMX   = 0.0;
% % %     hlx   = 0.0;
% % %     ZM    = 0.0;
% % % 
% % %     for I = 1 : NK
% % %         W_wt = (FV(KB + I) - fw)^2;
% % %         ratio_fc = min(0.9999, FV(KB + I) / P.FC);
% % %         r    = min(-1e-7, 4.0 * log(ratio_fc));
% % %         zf   = sqrt(-2.0 * r);
% % %         for ii = 1 : 3
% % %             rf = 1.0 + zf - exp(zf);
% % %             gf = rf - zf;
% % %             zf = zf + (r - rf) / gf;
% % %         end
% % %         ZM    = zf;
% % %         hlx   = HMX;
% % %         HMX   = HT(KB + I) + P.SH * ZM;
% % %         SUMHW = SUMHW + HMX * W_wt;
% % %         SUMW  = SUMW + W_wt;
% % %     end
% % %     P.HMAX = SUMHW / max(1e-9, SUMW);
% % % 
% % %     HADJ = 0.0;
% % %     fadj = 0.0;
% % %     if P.NF >= 3
% % %         HADJ          = P.HMAX - HMX;
% % %         HT(P.KRM)     = HN + HADJ * 0.80;
% % %         HT(P.KRM - 1) = HT(P.KRM - 1) + (P.HMAX - hlx) * 0.40;
% % %         fchap         = P.FC * exp(0.25 * (ZM - P.SH * GMAX));
% % %         fadj          = fchap - FM;
% % %     end
% % %     P.PARHT    = P.HMAX - HT(P.KRM);
% % %     HT(P.KR)   = P.HMAX - 0.5 * P.PARHT;
% % %     z_half     = 0.5 * P.PARHT / P.SH;
% % %     FV(P.KR)   = P.FC * exp(0.25 * (1.0 + z_half - exp(z_half)));
% % %     P.KR       = P.KR + 1;
% % %     FV(P.KR)   = P.FC;
% % %     HT(P.KR)   = P.HMAX;
% % %     DEVN       = devn * 2.0 / (1.0 + MK - NK);
% % % 
% % %     if fnext ~= 0.0
% % %         P.FC = min(P.FC, fnext - 0.03);
% % %         dfc  = FV(P.KR) - P.FC;
% % %         FM   = FM - dfc;
% % %         DEVN = min(DEVN, 0.5 * (fnext - FM) / P.FC);
% % %         if dfc > 0.01
% % %             df = dfc / (FV(P.KR)^3);
% % %             for k_idx = 1 : P.KR
% % %                 FV(k_idx) = FV(k_idx) - df * (FV(k_idx)^3);
% % %             end
% % %             P.FA = P.FA - df * (P.FA^3);
% % %         end
% % %     end
% % % 
% % %     devf    = P.FC * DEVN + abs(fadj);
% % %     bavge   = -P.B(2, 6) - P.B(NK, 6);
% % %     devs    = P.SH / SHR * DEVN / bavge;
% % %     devh    = DEVN * P.PARHT / bavge + devs * P.SH * GMAX + abs(HADJ);
% % %     P.tcont = P.tcont + P.PARHT * (P.FC^2 + 0.5 * FM^2) / 1.5;
% % %     SSH     = P.SH;
% % %     if LOOP_final == 1
% % %         SSH = -P.SH;
% % %     end
% % %     if P.lbug >= -9
% % %         fprintf('PEAK%7.3f (%5.3f) MHz,  Height%6.1f (%4.1f) km.    ScaleHt%5.1f (%4.1f) km  SlabT%6.1f km\n', ...
% % %             P.FC, devf, P.HMAX, devh, SSH, devs, P.tcont / (P.FC^2));
% % %     end
% % %     FV(P.KR + 4) = devf;
% % %     HT(P.KR + 4) = devh;
% % %     FV(P.KV)     = P.FC;
% % % 
% % %     if QQ(1) > 1.0
% % %         numq = fix(QQ(1));
% % %         for j_idx = (numq + 1) : (numq + 4)
% % %             if j_idx <= numel(QQ) && QQ(j_idx) == -1.0
% % %                 return;
% % %             end
% % %         end
% % %         wf = 0.1 + 0.9 / P.NF;
% % %         fp = FV(P.KRM) * wf + FV(P.KRM - 1) * (1.0 - wf);
% % %         fp = min(fp, 0.98 * P.FC);
% % %         QQ(numq + 1) = max(fp, 0.90 * FM);
% % %         QQ(numq + 2) = P.FC;
% % %         QQ(numq + 3) = P.HMAX;
% % %         QQ(numq + 4) = SSH;
% % %         QQ(1)        = numq + 4;
% % %     end
% % % end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [M, B, Q, devn, P] = sub_solve(M, N, B, Q, QSET, devn, lbug, P)
    if N >= 0
        P.solve_NQ = N;
        P.solve_NP = N + 1;
        if M < N
            return;
        end

        K = 0;
        S = 0.0;
        while true
            K = K + 1;
            if K <= 17
                P.solve_WSETQ(K) = 0.0;
            end
            S  = 0.0;
            MK = M - K + 1;
            if MK <= 0
                break;
            end
            S = sum(B(K:M, K) .^ 2);
            if K == P.solve_NP
                break;
            end
            A = B(K, K);
            D = sign_fortran(sqrt(S), A);
            B(K, K) = A + D;
            C = A * D + S;
            if C == 0.0
                M = -M;
                return;
            end
            for J = (K + 1) : P.solve_NP
                S_dot = sum(B(K:M, K) .* B(K:M, J)) / C;
                B(K:M, J) = B(K:M, J) - B(K:M, K) * S_dot;
            end
            B(K, K) = -D;
        end

        B(P.solve_NP, 1)          = M;
        B(P.solve_NP, P.solve_NP) = sqrt(S);
    else
        ww  = abs(M) / 100.0;
        nad = fix(abs(N) / 100);
        if nad > 0
            df = devn;
            fj = 1.0;
            if nad > 1
                fj = 1.0 / df;
            end
            nn = max(1, nad - 1);
            for j = nn : P.solve_NQ
                fj = fj * df;
                qj = fj;
                if nad > 1, qj = qj * j;       end
                if nad > 2, qj = qj * (j - 1); end
                Q(j) = qj * ww;
            end
            Q(P.solve_NP) = QSET * ww;
            REMOV = 1.0;
            [B, Q] = solve_givens_step(nn, P.solve_NP, nad, REMOV, B, Q);
        else
            REMOV = -1.0;
            NN    = abs(N) - 1;
            while true
                NN = NN + 1;
                if NN <= 17 && P.solve_WSETQ(NN) ~= 0.0
                    Q(NN)             = P.solve_WSETQ(NN);
                    Q(P.solve_NP)     = P.solve_WSETQ(NN) * P.solve_VSETQ(NN);
                    P.solve_WSETQ(NN) = 0.0;
                    [B, Q] = solve_givens_step(NN, P.solve_NP, nad, REMOV, B, Q);
                end
                if ~(NN < P.solve_NQ && M < 0)
                    break;
                end
            end

            REMOV = 1.0;
            NN    = abs(N);
            P.solve_WSETQ(NN) = ww;
            if M ~= 0
                P.solve_VSETQ(NN) = QSET;
                Q(NN)         = P.solve_WSETQ(NN);
                Q(P.solve_NP) = P.solve_WSETQ(NN) * P.solve_VSETQ(NN);
                [B, Q] = solve_givens_step(NN, P.solve_NP, nad, REMOV, B, Q);
            end
        end
    end

    devn = abs(B(P.solve_NP, P.solve_NP)) / sqrt(max(1.0, B(P.solve_NP, 1)));
    for II = 2 : P.solve_NP
        I = P.solve_NP - II + 1;
        S = B(I, P.solve_NP);
        if II > 2
            for J = (I + 1) : P.solve_NQ
                S = S - Q(J) * B(I, J);
            end
        end
        Q(I) = S / B(I, I);
    end
    Q(19) = Q(20);
    Q(20) = devn;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    P.Q = Q;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end

% % function [B, Q] = solve_givens_step(NN, NP, nad, REMOV, B, Q)
% %     for I = NN : NP
% %         BII = B(I, I);
% %         R   = sqrt(max(BII^2 + (Q(I)^2) * REMOV, 0.1e-9));
% %         C   = BII / R;
% %         S   = Q(I) / R;
% %         for J = I : NP
% %             QJ = Q(J);
% %             if I == NN && J ~= I && J ~= NP && nad == 0
% %                 QJ = 0.0;
% %             end
% %             Q(J)    = C * QJ - S * B(I, J);
% %             B(I, J) = C * B(I, J) + S * QJ * REMOV;
% %         end
% %     end
% % end


function [B, Q] = solve_givens_step(NN, NP, nad, REMOV, B, Q)
for I = NN : NP
    BII = B(I, I);
    R   = sqrt(max(BII^2 + (Q(I)^2) * REMOV, 0.1e-9));
    if R == 0.0
        continue;
    end
    C   = BII / R;
    S   = Q(I) / R;

    for J = I : NP
        if J < NP
            % Обработка столбцов треугольной матрицы B
            B_IJ = B(I, J);
            QJ   = Q(J);
            if I == NN && J ~= I && nad == 0
                QJ = 0.0;
            end
            Q(J)    = C * QJ - S * B_IJ;
            B(I, J) = C * B_IJ + S * QJ * REMOV;
        else
            % Обработка правого столбца (RHS), хранящегося в B(I, NP)
            B_INP = B(I, NP);
            Q_NP  = Q(NP);
            Q(NP)    = C * Q_NP - S * B_INP;
            B(I, NP) = C * B_INP + S * Q_NP * REMOV;
        end
    end
end
end

function res = fn_sumval(N, A, B, L)
    if N <= 0
        res = 0.0;
        return;
    end
    J = N;
    if L == 3
        J = N - 1;
    end
    S  = 0.0;
    JD = 1;
    if L > 4
        JD = L;
    end
    JB = (N - 1) * JD + 1;
    LL = min(L, 4);
    b1 = B(1);

    while J > 0
        switch LL
            case 1
                S = (S + A(J)) * b1;
            case 2
                S = S * b1 + A(J) * J;
            case 3
                S = S * b1 + A(J + 1) * (J + 1) * J;
            case 4
                S  = S + A(J) * B(JB);
                JB = JB - JD;
        end
        J = J - 1;
    end
    res = S;
end

function [gind_out, P] = fn_gind(F, T, P)
    if F == 0.0
        if ~(P.gind_GH < 0.0 || T < 2.0)
            P.gind_FH    = P.gind_GH / ((1.0 + T / 6371.2)^3);
            P.gind_FHSN  = P.gind_GHSN * P.gind_FH / P.gind_GH;
            P.gind_FCSCT = P.gind_GCSCT * P.gind_FH / P.gind_GH;
            P.gind_HFH   = 0.5 * P.gind_FHSN;
            P.gind_C     = P.gind_FCSCT + P.gind_FHSN;
            P.gind_C2    = P.gind_C * P.gind_C;
        end
        gind_out = P.gind_FH;
        return;
    elseif T < 0.0
        P.gind_GH    = F;
        P.gind_FH    = abs(P.gind_GH);
        DIP_rad      = max(-0.01745329 * T, 0.001);
        P.gind_GHSN  = P.gind_GH * sin(DIP_rad);
        P.gind_GCSCT = ((P.gind_GH * cos(DIP_rad))^2) * 0.5 / P.gind_GHSN;
        P.gind_FHSN  = P.gind_GHSN * P.gind_FH / P.gind_GH;
        P.gind_FCSCT = P.gind_GCSCT * P.gind_FH / P.gind_GH;
        P.gind_HFH   = 0.5 * P.gind_FHSN;
        P.gind_C     = P.gind_FCSCT + P.gind_FHSN;
        P.gind_C2    = P.gind_C * P.gind_C;
        gind_out     = P.gind_FH;
        return;
    end

    T2 = max(T, 0.1e-9)^2;
    if F < 0.0
        X  = (F + P.gind_FH) * T2;
        G1 = X - P.gind_FH;
    else
        G1 = F * T2;
    end
    G2 = P.gind_FCSCT / G1;
    G3 = sqrt(G2 * G2 + 1.0);
    if F < 0.0
        G4 = P.gind_FHSN * (G3 - G2);
        X  = X * (G1 - P.gind_FH);
        G5 = -G4 * X / (P.gind_FHSN * (sqrt(X + P.gind_C2) + P.gind_C));
    else
        G4 = P.gind_FHSN / (G2 + G3);
        G5 = G1 + G4;
    end
    G6 = F + G4;
    G7 = (F * G2 * G4 / G1 - P.gind_HFH) * (F - G1) / (G3 * G6);
    gind_out = abs(G7 + G6) / sqrt(G5 * G6) - 1.0;
end

function sub_trace(FV, HT, TRAS, P)
    if abs(P.lbug) > 9
        return;
    end
    if TRAS == 0.0
        fprintf(' #FRQ'); fprintf('%8.2f', FV(1:15)); fprintf('\n');
        fprintf(' #HTS'); fprintf('%8.2f', HT(1:15)); fprintf('\n');
        return;
    end
    if abs(TRAS - 2.2) < 1e-5
        fprintf('---------------------------------------------------------\n');
        fprintf('#TRACE:  kr  lk jm mt    ha     fa   frm    fm   kv  nf  nr nl nx ms  mode mod     hs    fc   fcc    sh   parht   hval vwidth vdepth\n');
    end
    FRM = FV(max(1, P.KRM));
    FM  = FV(max(1, P.MF));
    fprintf('#=%4.1f:%4d%4d%3d%3d%8.2f%6.2f%6.2f%6.2f%4d%4d%4d%3d%3d%3d%5d%4d   %6.2f%6.2f%6.2f%6.2f%7.2f%7.2f%7.2f%7.2f\n', ...
        TRAS, P.KR, P.LK, P.JM, P.MT, P.HA, P.FA, FRM, FM, P.KV, P.NF, P.NR, P.NL, P.NX, P.MS, ...
        P.MODE, P.MOD, P.HS, P.FC, P.FCC, P.SH, P.PARHT, P.HVAL, P.VWIDTH, P.VDEPTH);
end

function val = sign_fortran(a, b)
    if b >= 0.0
        val = abs(a);
    else
        val = -abs(a);
    end
end