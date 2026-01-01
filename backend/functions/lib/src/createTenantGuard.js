"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __generator = (this && this.__generator) || function (thisArg, body) {
    var _ = { label: 0, sent: function() { if (t[0] & 1) throw t[1]; return t[1]; }, trys: [], ops: [] }, f, y, t, g = Object.create((typeof Iterator === "function" ? Iterator : Object).prototype);
    return g.next = verb(0), g["throw"] = verb(1), g["return"] = verb(2), typeof Symbol === "function" && (g[Symbol.iterator] = function() { return this; }), g;
    function verb(n) { return function (v) { return step([n, v]); }; }
    function step(op) {
        if (f) throw new TypeError("Generator is already executing.");
        while (g && (g = 0, op[0] && (_ = 0)), _) try {
            if (f = 1, y && (t = op[0] & 2 ? y["return"] : op[0] ? y["throw"] || ((t = y["return"]) && t.call(y), 0) : y.next) && !(t = t.call(y, op[1])).done) return t;
            if (y = 0, t) op = [op[0] & 2, t.value];
            switch (op[0]) {
                case 0: case 1: t = op; break;
                case 4: _.label++; return { value: op[1], done: false };
                case 5: _.label++; y = op[1]; op = [0]; continue;
                case 7: op = _.ops.pop(); _.trys.pop(); continue;
                default:
                    if (!(t = _.trys, t = t.length > 0 && t[t.length - 1]) && (op[0] === 6 || op[0] === 2)) { _ = 0; continue; }
                    if (op[0] === 3 && (!t || (op[1] > t[0] && op[1] < t[3]))) { _.label = op[1]; break; }
                    if (op[0] === 6 && _.label < t[1]) { _.label = t[1]; t = op; break; }
                    if (t && _.label < t[2]) { _.label = t[2]; _.ops.push(op); break; }
                    if (t[2]) _.ops.pop();
                    _.trys.pop(); continue;
            }
            op = body.call(thisArg, _);
        } catch (e) { op = [6, e]; y = 0; } finally { f = t = 0; }
        if (op[0] & 5) throw op[1]; return { value: op[0] ? op[1] : void 0, done: true };
    }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.createTenantGuard = void 0;
var functions = __importStar(require("firebase-functions"));
var admin = __importStar(require("firebase-admin"));
var createTenantGuard = function (data, context) { return __awaiter(void 0, void 0, void 0, function () {
    var db, IN_PROGRESS_STATUSES, uid, businessName, documentBase64, packageId, q, _i, _a, doc, data_1, status, now, docRef, payload;
    var _b;
    return __generator(this, function (_c) {
        switch (_c.label) {
            case 0:
                if (admin.apps.length === 0) {
                    admin.initializeApp();
                }
                db = admin.firestore();
                IN_PROGRESS_STATUSES = ['draft', 'awaiting_payment', 'awaiting_confirmation', 'payment_submitted', 'waiting_proof'];
                uid = (_b = context.auth) === null || _b === void 0 ? void 0 : _b.uid;
                if (!uid) {
                    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
                }
                businessName = (data.businessName || '').toString();
                documentBase64 = (data.documentBase64 || '').toString();
                packageId = (data.packageId || 'basic').toString();
                if (businessName.trim().length === 0 || documentBase64.trim().length === 0) {
                    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
                }
                return [4 /*yield*/, db.collection('tenants').where('owner_uid', '==', uid).get()];
            case 1:
                q = _c.sent();
                for (_i = 0, _a = q.docs; _i < _a.length; _i++) {
                    doc = _a[_i];
                    data_1 = doc.data();
                    status = (data_1.status || '').toString();
                    if (IN_PROGRESS_STATUSES.includes(status)) {
                        throw new functions.https.HttpsError('failed-precondition', 'Existing active registration', { tenantId: doc.id, status: status });
                    }
                }
                now = admin.firestore.Timestamp.now();
                docRef = db.collection('tenants').doc();
                payload = {
                    owner_uid: uid,
                    business_name: businessName,
                    document_base64: documentBase64,
                    package_id: packageId,
                    status: 'draft',
                    created_at: now,
                    updated_at: now,
                };
                return [4 /*yield*/, docRef.set(payload)];
            case 2:
                _c.sent();
                return [2 /*return*/, { tenantId: docRef.id }];
        }
    });
}); };
exports.createTenantGuard = createTenantGuard;
