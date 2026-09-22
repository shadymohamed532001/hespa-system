import { AuthService } from './auth.service.js';
import { LoginDto } from './dto/login.dto.js';
export declare class AuthController {
    private readonly auth;
    constructor(auth: AuthService);
    login(dto: LoginDto): Promise<{
        accessToken: string;
        user: {
            id: string;
            username: string;
            role: import("../database/enums.js").UserRole;
        };
    }>;
    me(request: {
        user: unknown;
    }): unknown;
}
