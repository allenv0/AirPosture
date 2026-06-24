export function removeUndefinedFields<T>(obj: T): T {
    const newObj: any = { ...obj };
    Object.keys(newObj).forEach((key) => {
        if (newObj[key] === undefined) {
        delete newObj[key];
        }
    });
    return newObj;
}
